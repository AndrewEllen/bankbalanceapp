import 'package:flutter/material.dart';
import 'dart:math';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/main_balance_indicator.dart';
import '../widgets/transaction_box.dart';
import '../repositories/recurring_income_repository.dart';
import '../repositories/pay_period_instance_repository.dart';
import '../repositories/recurring_expense_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/balance_repository.dart';
import '../repositories/break_rules_repository.dart';
import '../models/recurring_income.dart';
import '../models/pay_period_instance.dart';
import '../models/recurring_expense.dart';
import '../models/expense.dart';
import '../services/deductions_service.dart';
import '../extensions/recurring_extensions.dart';
import '../models/transaction_model.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

/// Internal record pairing a [TransactionModel] with an optional originating
/// [Expense] object. When [expense] is provided the transaction represents
/// a one‑off expense that can be edited or deleted; otherwise it is a pay
/// period income and should not be editable.
class _Record {
  final TransactionModel model;
  final Expense? expense;
  _Record({required this.model, this.expense});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DraggableScrollableController _customScrollController = DraggableScrollableController();
  double _sheetSize = 0.6;
  bool _refreshing = false;

  // Financial data used for upcoming summaries and balance calculation.
  List<Widget> _financeItems = [];
  double _balance = 0.0;

  // Repositories for incomes, pay periods, expenses and balance.
  final _incomeRepo = RecurringIncomeRepository();
  final _instRepo = PayPeriodInstanceRepository();
  final _recExpRepo = RecurringExpenseRepository();
  final _expRepo = ExpenseRepository();
  final _balRepo = BalanceRepository();
  final _deductionsService = const DeductionsService();
  final _breakRepo = BreakRulesRepository();

  @override
  void initState() {
    super.initState();
    _customScrollController.addListener(() {
      setState(() {
        _sheetSize = _customScrollController.size;
      });
    });
    _loadFinancialData();
  }

  @override
  void dispose() {
    _customScrollController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _refreshing = true;
    });
    await _loadFinancialData();
    // Wait a short duration to allow the pull-to-refresh indicator to show
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _refreshing = false;
    });
  }

  /// Compute financial summaries and update [_financeItems] and [_balance].
  Future<void> _loadFinancialData() async {
    final now = DateTime.now();
    // Load manual balance and its timestamp. If the balance was set
    // recently, past incomes/expenses before the timestamp should not
    // influence the computed current balance.
    final balData = await _balRepo.getBalanceData();
    final manualBalance = balData['value'] as double;
    final DateTime manualDate = balData['timestamp'] as DateTime;
    double pastIncomeSum = 0.0;
    double pastExpenseSum = 0.0;
    double upcomingIncomeSum = 0.0;
    double upcomingExpenseSum = 0.0;
    // Load templates and map by id for quick lookup.
    final templates = await _incomeRepo.load();
    final Map<String, RecurringIncome> templateMap = {for (final t in templates) t.id: t};
    // Load all pay period instances.
    final instances = await _instRepo.loadAll();
    // Compute amounts for each instance.
    for (final inst in instances) {
      final t = templateMap[inst.templateId];
      if (t == null || !t.enabled) continue;
      final amount = await _computeIncomeAmount(inst, t);
      // Only include past incomes that occurred after the manual balance date
      if (!inst.paymentDate.isAfter(now)) {
        if (!inst.paymentDate.isBefore(manualDate)) {
          pastIncomeSum += amount;
        }
      } else {
        // upcoming; include only those within next 30 days for the upcoming summary.
        if (inst.paymentDate.difference(now).inDays <= 30) {
          upcomingIncomeSum += amount;
        }
      }
    }
    // Recurring expenses.
    final recExps = await _recExpRepo.loadAll();
    for (final e in recExps) {
      if (!e.enabled) continue;
      // Determine all payment dates up to a reasonable horizon (next 30 days) and accumulate.
      DateTime next = e.firstPaymentDate;
      // Move next to the first occurrence on or after a baseline (year 2000). We'll adjust in loop.
      // We want to account for multiple missed payments in the past.
      while (next.isBefore(now)) {
        // Only accumulate past expenses after manual balance date
        if (!next.isBefore(manualDate)) {
          pastExpenseSum += e.amount;
        }
        next = _addCycle(next, e.cycle);
      }
      // Now next is on or after now. Accumulate upcoming payments up to 30 days.
      while (next.isAfter(now) && next.difference(now).inDays <= 30) {
        upcomingExpenseSum += e.amount;
        next = _addCycle(next, e.cycle);
      }
    }
    // One‑off expenses.
    final exps = await _expRepo.loadAll();
    for (final exp in exps) {
      if (!exp.date.isAfter(now)) {
        // Only include transactions dated after manual balance date
        if (!exp.date.isBefore(manualDate)) {
          if (exp.income) {
            pastIncomeSum += exp.amount;
          } else {
            pastExpenseSum += exp.amount;
          }
        }
      } else if (exp.date.difference(now).inDays <= 30) {
        // Upcoming within 30 days
        if (exp.income) {
          upcomingIncomeSum += exp.amount;
        } else {
          upcomingExpenseSum += exp.amount;
        }
      }
    }
    // Compute current balance: manual base + past incomes - past expenses.
    final currentBalance = manualBalance + pastIncomeSum - pastExpenseSum;
    // Build widgets list. First add upcoming summary and log buttons.
    final List<Widget> items = [];
    items.add(_buildUpcomingSummaryRow(upcomingIncomeSum, upcomingExpenseSum));
    items.add(_buildLogExpenseRow());

    // Build transaction records for past incomes and one‑off expenses after manual date.
    final List<_Record> records = [];
    // Past incomes from pay period instances
    for (final inst in instances) {
      final t = templateMap[inst.templateId];
      if (t == null || !t.enabled) continue;
      if (!inst.paymentDate.isAfter(now) && !inst.paymentDate.isBefore(manualDate)) {
        final amount = await _computeIncomeAmount(inst, t);
        // Skip zero amounts
        if (amount > 0) {
          final tm = TransactionModel(
            transactionAmount: amount,
            transactionTime: inst.paymentDate,
            income: true,
            category: 'Income',
            description: t.name,
          );
          records.add(_Record(model: tm));
        }
      }
    }
    // Past one‑off expenses/incomes
    for (final exp in exps) {
      if (!exp.date.isAfter(now) && !exp.date.isBefore(manualDate)) {
        final tm = TransactionModel(
          transactionAmount: exp.amount,
          transactionTime: exp.date,
          income: exp.income,
          category: exp.category,
          description: exp.name,
        );
        records.add(_Record(model: tm, expense: exp));
      }
    }
    // Sort by date descending (most recent first)
    records.sort((a, b) => b.model.transactionTime.compareTo(a.model.transactionTime));
    // Append a widget for each record. Use TransactionItem for incomes; for expenses attach edit/delete.
    int transIndex = 0;
    for (final rec in records) {
      if (rec.expense != null) {
        items.add(_buildExpenseItem(rec.expense!));
      } else {
        items.add(TransactionItem(index: transIndex++, model: rec.model));
      }
    }
    if (mounted) {
      setState(() {
        _financeItems = items;
        _balance = currentBalance;
      });
    }
  }

  /// Build a card displaying a one‑off expense. Includes edit and delete
  /// actions. Editing opens the same modal as logging an expense but
  /// pre‑populated with the expense's details.
  Widget _buildExpenseItem(Expense exp) {
    final df = DateFormat.yMMMEd();
    return Card(
      color: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          exp.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              df.format(exp.date),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (exp.category != null)
              Text(
                exp.category!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${exp.income ? '+' : '-'}£${exp.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: exp.income ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white70),
              onPressed: () async {
                await _showEditExpenseDialog(exp);
                await _loadFinancialData();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white70),
              onPressed: () async {
                await _expRepo.delete(exp.id);
                await _loadFinancialData();
              },
            ),
          ],
        ),
      ),
    );
  }


  /// Add a cycle interval to a date based on [cycle]. Mirrors the logic used
  /// in recurring income. For weekly cycles it adds 7/14/28 days; for monthly
  /// it adds one month keeping the same day of month if possible.
  DateTime _addCycle(DateTime date, PayCycle cycle) {
    switch (cycle) {
      case PayCycle.everyWeek:
        return date.add(const Duration(days: 7));
      case PayCycle.every2Weeks:
        return date.add(const Duration(days: 14));
      case PayCycle.every4Weeks:
        return date.add(const Duration(days: 28));
      case PayCycle.monthly:
        return DateTime(date.year, date.month + 1, date.day);
    }
  }

  /// Compute the paid amount for a pay period instance belonging to template [t].
  /// This replicates the logic used in [PayPeriodInstancesListView] to ensure
  /// consistency of break deductions, overtime cut‑offs and deductions. For
  /// advanced templates the hourly net (or gross) is computed; for simple
  /// templates the override amount or template amount is returned.
  Future<double> _computeIncomeAmount(PayPeriodInstance inst, RecurringIncome t) async {
    if (t.advanced && (t.hourly ?? 0) > 0) {
      double dayPaidIncluded = 0.0;
      double carryOutPaid = 0.0;
      for (final d in inst.days) {
        final baseOnly = await _paidHoursAfterBreaks(d.baseHours);
        final withExtra = await _paidHoursAfterBreaks(d.baseHours + d.extraHours);
        final extraPaidPortion = (withExtra - baseOnly).clamp(0, double.infinity);
        if (_isAfterOtCutoff(d.date, inst.paymentDate)) {
          carryOutPaid += extraPaidPortion;
          dayPaidIncluded += baseOnly;
        } else {
          dayPaidIncluded += withExtra;
        }
      }
      final totalPaid = dayPaidIncluded + inst.carryInHours + inst.manualAdjustment;
      final hourlyRate = t.hourly ?? 0;
      final gross = totalPaid * hourlyRate;
      double amountValue;
      if (hourlyRate == 0) {
        amountValue = 0;
      } else if (t.deductions != null) {
        final ded = _deductionsService.computeNetForPeriod(
          periodGross: gross,
          periodsPerYear: t.cycle.periodsPerYear,
          s: t.deductions!,
        );
        final net = ded['net'] ?? gross;
        amountValue = net;
      } else {
        amountValue = gross;
      }
      return amountValue;
    } else {
      final amt = inst.simpleOverrideAmount ?? t.amount;
      return amt;
    }
  }

  /// Compute paid hours after breaks for a given number of hours. Uses
  /// [_breakRepo] to determine the break deduction in minutes. Returned hours
  /// are never negative.
  Future<double> _paidHoursAfterBreaks(double hours) async {
    final breakMin = await _breakRepo.breakFor(hours);
    final paid = ((hours * 60) - breakMin) / 60.0;
    return paid < 0 ? 0 : paid;
  }

  /// Determine whether a date lies on or after the overtime cut‑off for a
  /// period ending on payday. Week 4 Monday minus 7 days gives Week 3
  /// Monday; adding 2 days gives Wednesday of Week 3. Dates on/after this
  /// cut‑off are carried into the next period.
  bool _isAfterOtCutoff(DateTime date, DateTime payday) {
    // For 4‑week cycles, payday is the last day of W4; for 2 week cycles it is
    // end of W2; for weekly cycles it is end of W1; monthly uses W4 logic as
    // there is no overtime cut‑off concept for monthly but we'll reuse W3
    // Wednesday. The existing implementation in PayPeriodInstancesListView
    // simply uses the payday and subtracts accordingly.
    final int diff = payday.weekday - DateTime.monday;
    final week4Monday = DateTime(payday.year, payday.month, payday.day).subtract(Duration(days: diff));
    final week3Monday = week4Monday.subtract(const Duration(days: 7));
    final cutoff = week3Monday.add(const Duration(days: 2)); // Wednesday of W3
    return date.isAfter(cutoff) || date.isAtSameMomentAs(cutoff);
  }

  /// Build a summary row showing upcoming incomes and expenses within 30 days.
  Widget _buildUpcomingSummaryRow(double incomeTotal, double expenseTotal) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming (30 days)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Income',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              ),
              Text(
                '£${incomeTotal.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expenses',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              ),
              Text(
                '£${expenseTotal.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build a row that allows the user to log a one‑off expense quickly. Tapping
  /// the row opens a bottom sheet where the user can enter the amount and a
  /// description. The new expense is saved and the financial data is
  /// reloaded.
  Widget _buildLogExpenseRow() {
    return GestureDetector(
      onTap: () async {
        await _showLogExpenseDialog();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Log expense',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Icon(Icons.add, color: Colors.white),
          ],
        ),
      ),
    );
  }

  /// Present a dialog allowing the user to log a one‑off expense. On save
  /// the expense is persisted and the financial data reloaded.
  Future<void> _showLogExpenseDialog() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime date = DateTime.now();
    bool isIncome = false;
    String? selectedCategory;
    final categories = [
      'Grocery',
      'Transport',
      'Dining',
      'Entertainment',
      'Subscription',
      'Transfer',
      'Refund',
      'Fuel',
      'From Friend',
      'Income',
    ];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Log Transaction',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const SizedBox(height: 12),
                    // Type selector: expense vs income
                    Row(
                      children: [
                        const Text('Income', style: TextStyle(color: Colors.white70)),
                        const SizedBox(width: 12),
                        Switch(
                          value: isIncome,
                          onChanged: (val) {
                            setModalState(() {
                              isIncome = val;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(isIncome ? 'Income' : 'Expense', style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Category selector
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                      dropdownColor: Colors.black,
                      value: selectedCategory,
                      items: categories
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, style: const TextStyle(color: Colors.white)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setModalState(() {
                          selectedCategory = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '£',
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Date', style: TextStyle(color: Colors.white70)),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Colors.deepPurple,
                                      onPrimary: Colors.white,
                                      surface: Color(0xFF1C1C1E),
                                      onSurface: Colors.white,
                                    ),
                                    dialogBackgroundColor: Colors.black,
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setModalState(() {
                                date = picked;
                              });
                            }
                          },
                          child: Text(
                            DateFormat.yMMMEd().format(date),
                            style: const TextStyle(color: Colors.deepPurple),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final desc = nameCtrl.text.trim();
                            final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                            if (desc.isEmpty || amt <= 0 || selectedCategory == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Enter description, amount and category')),
                              );
                              return;
                            }
                            final expense = Expense(
                              id: const Uuid().v4(),
                              name: desc,
                              amount: amt,
                              date: date,
                              income: isIncome,
                              category: selectedCategory,
                            );
                            await _expRepo.add(expense);
                            Navigator.pop(context);
                            await _loadFinancialData();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    // Do not dispose controllers here.
  }

  /// Present a dialog for editing an existing expense. Pre‑populates the
  /// fields with the expense's details. Saving updates the expense via
  /// upsert, deleting via delete.
  Future<void> _showEditExpenseDialog(Expense exp) async {
    final nameCtrl = TextEditingController(text: exp.name);
    final amountCtrl = TextEditingController(text: exp.amount.toString());
    DateTime date = exp.date;
    bool isIncome = exp.income;
    String? selectedCategory = exp.category;
    final categories = [
      'Grocery',
      'Transport',
      'Dining',
      'Entertainment',
      'Subscription',
      'Transfer',
      'Refund',
      'Fuel',
      'From Friend',
      'Income',
    ];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Transaction',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Income', style: TextStyle(color: Colors.white70)),
                        const SizedBox(width: 12),
                        Switch(
                          value: isIncome,
                          onChanged: (val) {
                            setModalState(() {
                              isIncome = val;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(isIncome ? 'Income' : 'Expense', style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                      dropdownColor: Colors.black,
                      value: selectedCategory,
                      items: categories
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, style: const TextStyle(color: Colors.white)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setModalState(() {
                          selectedCategory = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '£',
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Date', style: TextStyle(color: Colors.white70)),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Colors.deepPurple,
                                      onPrimary: Colors.white,
                                      surface: Color(0xFF1C1C1E),
                                      onSurface: Colors.white,
                                    ),
                                    dialogBackgroundColor: Colors.black,
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setModalState(() {
                                date = picked;
                              });
                            }
                          },
                          child: Text(
                            DateFormat.yMMMEd().format(date),
                            style: const TextStyle(color: Colors.deepPurple),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final desc = nameCtrl.text.trim();
                            final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                            if (desc.isEmpty || amt <= 0 || selectedCategory == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Enter description, amount and category')),
                              );
                              return;
                            }
                            final updated = Expense(
                              id: exp.id,
                              name: desc,
                              amount: amt,
                              date: date,
                              income: isIncome,
                              category: selectedCategory,
                            );
                            await _expRepo.upsert(updated);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    // Do not dispose controllers
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.black,

      body: RefreshIndicator(
        backgroundColor: _refreshing ? Colors.transparent : null,
        color: _refreshing ? Colors.transparent : null,
        onRefresh: _handleRefresh,
        child: Stack(
          children: [

            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Transform.translate(
                    offset: Offset(0, -(1-(0.6/_sheetSize))*100),
                    child: Transform.scale(
                      scale: (() {
                        final t = ((_sheetSize - 0.6) / 0.3).clamp(0.0, 1.0);
                        final easedT = t * t; // equivalent to pow(t, 2)
                        return 1.0 - easedT * 0.15;
                      })(),

                      child: MainBalanceIndicator(
                        refreshing: _refreshing,
                        balance: _balance,
                      ),
                    ),
                  ),
              ),
            ),


            DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.6,
              maxChildSize: 0.9,
              controller: _customScrollController,
              snap: true,
              snapAnimationDuration: Duration(milliseconds: 200),
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(26, 26, 27, 1.0),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black, // very dark
                        blurRadius: 20,                       // thick + soft edges
                        spreadRadius: 0,                      // makes it larger
                        offset: Offset(0, -25),                // shadow below the widget
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Actual scrollable list with additional finance items
                      ListView.builder(
                        controller: scrollController,
                        itemCount: _financeItems.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          return _financeItems[index];
                        },
                      ),

                      // Top fade
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 40,
                        child: IgnorePointer(
                          child: Container(
                            decoration: const BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color.fromRGBO(26, 26, 27, 1.0),
                                  Color.fromRGBO(26, 26, 27, 0.7),
                                  Color.fromRGBO(26, 26, 27, 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Bottom fade
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 40,
                        child: IgnorePointer(
                          child: Container(
                            decoration: const BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Color.fromRGBO(26, 26, 27, 1.0),
                                  Color.fromRGBO(26, 26, 27, 0.7),
                                  Color.fromRGBO(26, 26, 27, 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Drag handle
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 30,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(45),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                );
              },
            ),

            Positioned(
              // 60dp above the *safe* bottom on every device
              bottom: 10 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  // normalize the 1000 magic number to screen height
                  offset: Offset(
                    0,
                    (1 - (0.6 / _sheetSize)) *
                        MediaQuery.of(context).size.height * 0.90, // tweak 0.90 to taste
                  ),
                  child: const BottomNavBar(),
                ),
              ),
            )


          ],
        ),
      ),
    );
  }
}

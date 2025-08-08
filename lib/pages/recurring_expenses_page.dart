import 'package:flutter/material.dart';

import 'recurring_expenses_list_view.dart';
import 'recurring_expense_edit_page.dart';

/// A full page wrapper for the recurring expenses list. Displays a dark
/// scaffold with an AppBar and a floating action button for adding new
/// expenses. The body is provided by [RecurringExpensesListView].
class RecurringExpensesPage extends StatefulWidget {
  const RecurringExpensesPage({super.key});

  @override
  State<RecurringExpensesPage> createState() => _RecurringExpensesPageState();
}

class _RecurringExpensesPageState extends State<RecurringExpensesPage> {
  /// A key for the list view so we can trigger a rebuild when returning from
  /// the edit page. Changing the key forces the widget to rebuild.
  Key _listKey = UniqueKey();

  void _refreshList() {
    setState(() {
      _listKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Expenses'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecurringExpenseEditPage()),
          );
          _refreshList();
        },
        label: const Text('Add Expense'),
        icon: const Icon(Icons.add),
      ),
      body: RecurringExpensesListView(key: _listKey),
    );
  }
}
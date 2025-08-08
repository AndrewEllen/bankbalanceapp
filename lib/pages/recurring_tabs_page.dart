
import 'package:flutter/material.dart';
import 'recurring_income_list_page.dart';
import 'recurring_income_edit_page.dart';
import 'pay_period_instance_list_page.dart';

class RecurringTabsPage extends StatelessWidget {
  const RecurringTabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return Scaffold(
              floatingActionButton: tabController?.index == 1
                  ? FloatingActionButton.extended(
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringIncomeEditPage()));
                        // Optionally trigger reload logic if needed
                      },
                      label: const Text('Add Income'),
                    )
                  : null,
        appBar: AppBar(
          title: const Text('Recurring & Pay Periods'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pay periods'),
              Tab(text: 'Templates'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PayPeriodInstanceListPage(),
            RecurringIncomeListPage(),
          ],
        ),
          );
        }
      ),
    );
  }
}

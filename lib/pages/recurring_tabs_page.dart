import 'package:flutter/material.dart';
import 'recurring_income_list_page.dart';
import 'pay_period_instances_list_page.dart';

/// Hosts two tabs:
/// - Templates: the recurring income templates (reuses RecurringIncomeListView)
/// - Pay Periods: the editable live periods (list view placeholder for now)
class RecurringTabsPage extends StatelessWidget {
  const RecurringTabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pay'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pay periods', icon: Icon(Icons.view_week)),
              Tab(text: 'Templates', icon: Icon(Icons.repeat)),
            ],
          ),
        ),
        backgroundColor: Colors.black,
        body: const TabBarView(
          children: [
            // Reuse the *body-only* list view so we don't nest Scaffolds.
            PayPeriodInstancesListView(),
            RecurringIncomeListView(),
          ],
        ),
      ),
    );
  }
}
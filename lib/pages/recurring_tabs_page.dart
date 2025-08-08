
import 'package:flutter/material.dart';
import 'recurring_income_list_view.dart';
import 'recurring_income_edit_page.dart';
import 'pay_period_instances_list_view.dart';

class RecurringTabsPage extends StatelessWidget {
  const RecurringTabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          // Use an AnimatedBuilder so that changing tabs triggers a rebuild of
          // the floating action button visibility.
          return AnimatedBuilder(
            animation: controller!,
            builder: (context, _) {
              final index = controller.index;
              return Scaffold(
                backgroundColor: Colors.black,
                floatingActionButton: index == 1
                    ? FloatingActionButton.extended(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RecurringIncomeEditPage(),
                            ),
                          );
                          // Optionally trigger reload logic if needed
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Template'),
                      )
                    : null,
                appBar: AppBar(
                  title: const Text('Pay'),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  bottom: const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.view_week), text: 'Pay periods'),
                      Tab(icon: Icon(Icons.repeat), text: 'Templates'),
                    ],
                  ),
                ),
                body: const TabBarView(
                  children: [
                    PayPeriodInstancesListView(),
                    RecurringIncomeListView(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Placeholder for the pay periods list view.
/// This is intentionally scaffold-less so it can live inside the tabs page.
class PayPeriodInstancesListView extends StatelessWidget {
  const PayPeriodInstancesListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'Pay periods will appear here.\n\n'
          'This tab is the live, editable pay period view.\n'
          'Templates (recurring rules) are in the other tab.\n\n'
          'Implementation note: we keep this scaffold-less so it nests cleanly under the Tabs page.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
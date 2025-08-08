import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MainBalanceIndicator extends StatelessWidget {
  const MainBalanceIndicator({super.key, required this.refreshing, required this.balance});

  /// Whether the list is refreshing. When true the progress indicator
  /// animates indeterminately.
  final bool refreshing;

  /// The current balance to display. The caller is responsible for computing
  /// this value (manual balance plus incomes minus expenses). It will be
  /// formatted with two decimal places and a pound symbol.
  final double balance;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.of(context).size.height;
    final formatted = '£' + balance.toStringAsFixed(2);
    return Center(
      child: SizedBox(
        width: scale / 3.3333,
        height: scale / 3.3333,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 320,
                width: 320,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  value: refreshing ? null : 1,
                ),
              ),
            ),
            Positioned(
              bottom: -10,
              child: Container(
                height: 75,
                width: 200,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 20,
                      spreadRadius: 25,
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              bottom: 10,
              child: Text(
                'Balance',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
            ),
            Center(
              child: Text(
                formatted,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MainBalanceIndicator extends StatefulWidget {
  const MainBalanceIndicator({super.key, required this.refreshing});
  final bool refreshing;

  @override
  State<MainBalanceIndicator> createState() => _MainBalanceIndicatorState();
}

class _MainBalanceIndicatorState extends State<MainBalanceIndicator> {
  final double balance = 1256.12;

  @override
  Widget build(BuildContext context) {

    double scale = MediaQuery.of(context).size.height;

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
                  value: widget.refreshing ? null : 1,
                ),
              ),
            ),

            Positioned(
              bottom: -10,
              child: Container(
                height: 75,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black, // strong shadow
                      blurRadius: 20,                        // soft edges
                      spreadRadius: 25,                      // large area
                    ),
                  ],
                ),
              ),
            ),


            Positioned(
              bottom: 10,
              child: Text(
                "Balance",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 24
                ),
              ),
            ),

            Center(
              child: Text(
                "£1,256.12",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 36
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

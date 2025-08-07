import 'package:flutter/material.dart';
import 'dart:math';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/main_balance_indicator.dart';
import '../widgets/transaction_box.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DraggableScrollableController _customScrollController = DraggableScrollableController();
  double _sheetSize = 0.6;

  @override
  void initState() {
    super.initState();
    _customScrollController.addListener(() {
      setState(() {
        _sheetSize = _customScrollController.size;
      });
    });
  }


  @override
  void dispose() {
    _customScrollController.dispose();
    super.dispose();
  }


  bool _refreshing = false;

  Future<void> _handleRefresh() async {
    print("Refreshing");
    setState(() {
      _refreshing = true;
    });
    await Future.delayed(const Duration(seconds: 3));
    setState(() {
      _refreshing = false;
    });
    print("Refreshed");
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

                      child: MainBalanceIndicator(refreshing: _refreshing,),
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
                      // Actual scrollable list
                      ListView.builder(
                        controller: scrollController,
                        itemCount: 50,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          return TransactionItem(
                            index: index,
                            loading: _refreshing,
                          );
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

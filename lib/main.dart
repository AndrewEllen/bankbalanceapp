import 'package:bankbalanceapp/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/recurring_income_list_page.dart';
import 'pages/recurring_income_edit_page.dart';
import 'pages/break_rules_page.dart';
import 'pages/recurring_tabs_page.dart';
import 'pages/pay_period_instance_edit_page.dart';
import 'pages/recurring_expenses_page.dart';
import 'pages/recurring_expense_edit_page.dart';
import 'pages/settings_page.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(SafeArea(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bank Balance App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
      routes: {
        '/recurring/tabs': (_) => const RecurringTabsPage(),
        '/recurring': (_) => const RecurringIncomeListPage(),
        '/recurring/add': (_) => const RecurringIncomeEditPage(),
        '/break-rules': (_) => const BreakRulesPage(),
        '/expenses': (_) => const RecurringExpensesPage(),
        '/expenses/add': (_) => const RecurringExpenseEditPage(),
        '/settings': (_) => const SettingsPage(),
      },
    );
  }
}
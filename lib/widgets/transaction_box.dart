import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../models/transaction_model.dart'; // your model

class TransactionItem extends StatelessWidget {
  /// Index used when generating dummy data. Ignored when [model] is provided.
  final int index;
  final bool loading;
  /// Optional transaction model to display. When provided, the item uses
  /// [model] instead of generating random data. If null, dummy data is used.
  final TransactionModel? model;

  const TransactionItem({
    super.key,
    required this.index,
    this.loading = false,
    this.model,
  });

  TransactionModel _generateTransaction(int index) {
    final random = Random(index);

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

    final category = categories[index % categories.length];
    final baseAmount = double.parse((random.nextDouble() * 100).toStringAsFixed(2));
    final income = category == 'Income' || category == 'From Friend';
    final alwaysPositive = category == 'Refund' || income;
    final amount = alwaysPositive ? baseAmount : -baseAmount;
    final date = DateTime.now().subtract(Duration(days: random.nextInt(30)));

    return TransactionModel(
      transactionAmount: amount.abs(),
      transactionTime: date,
      income: amount > 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[850]!,
        highlightColor: Colors.grey[700]!,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[900]!.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side placeholders (category + date)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[800]!.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[800]!.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),

              // Right side placeholder (amount)
              Container(
                width: 60,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[800]!.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Actual transaction display. Use provided model if available, else dummy.
    final transaction = model ?? _generateTransaction(index);
    final currency = NumberFormat.currency(locale: 'en_GB', symbol: '£')
        .format(transaction.transactionAmount);
    final category = model?.category ?? _defaultCategoryForIndex(index);

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Category and Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd MMM yyyy').format(transaction.transactionTime),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),

          // Amount
          Text(
            '${transaction.income ? '+' : '-'}$currency',
            style: TextStyle(
              color: transaction.income ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Provide a deterministic default category for dummy transactions.
  String _defaultCategoryForIndex(int idx) {
    const categories = [
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
    return categories[idx % categories.length];
  }
}

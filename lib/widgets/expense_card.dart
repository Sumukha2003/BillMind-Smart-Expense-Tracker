import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onDelete;

  const ExpenseCard({super.key, required this.expense, this.onDelete});

  static const _colors = {
    'Food': Color(0xFF1D9E75),
    'Grocery': Color(0xFF378ADD),
    'Utility': Color(0xFFBA7517),
    'Medical': Color(0xFFD85A30),
    'Transport': Color(0xFF7F77DD),
    'Shopping': Color(0xFFD4537E),
    'Entertainment': Color(0xFF639922),
    'Other': Color(0xFF888780),
  };

  static const _icons = {
    'Food': Icons.restaurant,
    'Grocery': Icons.shopping_basket,
    'Utility': Icons.bolt,
    'Medical': Icons.local_hospital,
    'Transport': Icons.directions_car,
    'Shopping': Icons.shopping_bag,
    'Entertainment': Icons.movie,
    'Other': Icons.receipt,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[expense.category] ?? const Color(0xFF888780);
    final icon = _icons[expense.category] ?? Icons.receipt;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          expense.merchant,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                expense.category,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd MMM').format(expense.date),
              style: const TextStyle(fontSize: 11, color: Color(0xFFB4B2A9)),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rs ${NumberFormat('#,##,###.##').format(expense.amount)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Color(0xFFB4B2A9),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

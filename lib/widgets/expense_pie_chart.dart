import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';

class ExpensePieChart extends StatefulWidget {
  final Map<String, double> data;

  const ExpensePieChart({super.key, required this.data});

  @override
  State<ExpensePieChart> createState() => _ExpensePieChartState();
}

class _ExpensePieChartState extends State<ExpensePieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.isEmpty) return const Center(child: Text("No data"));

    final total = data.values.fold(0.0, (a, b) => a + b);
    final entries = data.entries.toList();
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = response.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sections: entries.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final percent = total == 0 ? 0 : item.value / total * 100;
                final isTouched = index == touchedIndex;

                return PieChartSectionData(
                  value: item.value,
                  title: '${percent.toStringAsFixed(1)}%',
                  color: Color(Expense.categoryColors[item.key] ?? 0xFF9E9E9E),
                  radius: isTouched ? 85 : 70,
                  titleStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isTouched ? 14 : 12,
                  ),
                );
              }).toList(),
            ),
            swapAnimationDuration: const Duration(milliseconds: 800),
            swapAnimationCurve: Curves.easeInOut,
          ),
        ),

        const SizedBox(height: 8),

        // Center label (Total or selected)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              touchedIndex == -1 ? 'Total' : entries[touchedIndex].key,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Builder(builder: (ctx) {
              if (touchedIndex == -1) {
                return Text('(${currency.format(total)})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
              }

              final sel = entries[touchedIndex];
              final percent = total == 0 ? 0 : sel.value / total * 100;
              return Text('${percent.toStringAsFixed(1)}% (${currency.format(sel.value)})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
            }),
          ],
        ),

        const SizedBox(height: 12),

        // Legend with exact values using category colors
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: entries.map((entry) {
            final color = Color(Expense.categoryColors[entry.key] ?? 0xFF9E9E9E);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('${entry.key} (${currency.format(entry.value)})'),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

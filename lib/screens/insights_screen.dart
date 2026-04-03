import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../services/analytics_service.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  static const _sectionTitleStyle = TextStyle(fontWeight: FontWeight.bold);

  int touchedIndex = -1;

  Future<void> _refreshInsights() async {
    ref.read(expenseNotifierProvider.notifier).refresh();
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final insights = ref.watch(insightsProvider);
    final selectedYear = ref.watch(selectedYearProvider);
    final expenses = ref.watch(selectedYearExpensesProvider);
    final categoryTotals = ref.watch(allCategoryTotalsProvider);
    final total = categoryTotals.values.fold(0.0, (a, b) => a + b);
    final entries = categoryTotals.entries.toList();
    final selectedIndex =
        touchedIndex >= 0 && touchedIndex < entries.length ? touchedIndex : -1;
    final surfaceColor = isDark ? const Color(0xFF151A18) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2A3430)
        : const Color(0xFFE3ECE7);
    final secondaryTextColor = isDark
        ? const Color(0xFFB6C2BD)
        : const Color(0xFF6B7B76);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights & Trends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshInsights,
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF0A0A0A), Color(0xFF111715)]
                : const [Color(0xFFF4FBF8), Color(0xFFFFFFFF)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refreshInsights,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Category Trends', style: _sectionTitleStyle),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_alt_rounded,
                        color: Color(0xFF1D9E75),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Year filter',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pie chart, trends, and totals update for the selected year.',
                              style: TextStyle(color: secondaryTextColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF101513)
                              : const Color(0xFFF9FCFB),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedYear,
                            borderRadius: BorderRadius.circular(16),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            items: kYearFilterOptions
                                .map(
                                  (year) => DropdownMenuItem<int>(
                                    value: year,
                                    child: Text(year.toString()),
                                  ),
                                )
                                .toList(),
                            onChanged: (year) {
                              if (year != null) {
                                ref.read(selectedYearProvider.notifier).state =
                                    year;
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Showing expenses recorded for $selectedYear only.',
                  style: TextStyle(color: secondaryTextColor),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                  ),
                  child: SizedBox(
                    height: 200,
                    child: entries.isEmpty
                        ? Center(
                            child: Text(
                              'No insights yet',
                              style: TextStyle(color: secondaryTextColor),
                            ),
                          )
                        : BarChart(
                            BarChartData(
                              barGroups: entries.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                return BarChartGroupData(
                                  x: index,
                                  barRods: [
                                    BarChartRodData(
                                      toY: item.value,
                                      color: Color(
                                        Expense.categoryColors[item.key] ??
                                            0xFF9E9E9E,
                                      ),
                                      width: 16,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                );
                              }).toList(),
                              titlesData: const FlTitlesData(show: true),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text('Expense Distribution', style: _sectionTitleStyle),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                  ),
                  child: SizedBox(
                    height: 280,
                    child: entries.isEmpty
                        ? Center(
                            child: Text(
                              'No category data to display',
                              style: TextStyle(color: secondaryTextColor),
                            ),
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
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
                                        touchedIndex = response.touchedSection!
                                            .touchedSectionIndex;
                                      });
                                    },
                                  ),
                                  sections: entries.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final item = entry.value;
                                    final percentage = total == 0
                                        ? 0
                                        : (item.value / total) * 100;
                                    final isTouched = index == selectedIndex;

                                    return PieChartSectionData(
                                      value: item.value,
                                      title:
                                          '${percentage.toStringAsFixed(1)}%',
                                      color: Color(
                                        Expense.categoryColors[item.key] ??
                                            0xFF9E9E9E,
                                      ),
                                      radius: isTouched ? 85 : 70,
                                      titleStyle: TextStyle(
                                        fontSize: isTouched ? 14 : 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                                ),
                                swapAnimationDuration: const Duration(
                                  milliseconds: 800,
                                ),
                                swapAnimationCurve: Curves.easeInOut,
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    selectedIndex == -1
                                        ? 'Total'
                                        : entries[selectedIndex].key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedIndex == -1
                                        ? 'Rs ${total.toStringAsFixed(0)}'
                                        : 'Rs ${entries[selectedIndex].value.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: entries.map((entry) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Color(
                              Expense.categoryColors[entry.key] ?? 0xFF9E9E9E,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(entry.key),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 30),
                const Text('Insights', style: _sectionTitleStyle),
                const SizedBox(height: 10),
                ...insights.map(
                  (insight) => Card(
                    color: surfaceColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: borderColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        insight,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text('Recurring Vendors', style: _sectionTitleStyle),
                const SizedBox(height: 10),
                ...AnalyticsService.detectRecurring(expenses).map(
                  (vendor) => Card(
                    color: surfaceColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: borderColor),
                    ),
                    child: ListTile(
                      title: Text(vendor),
                      subtitle: Text(
                        'Saved bills stay available after restart.',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      trailing: const Icon(Icons.notifications_active),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

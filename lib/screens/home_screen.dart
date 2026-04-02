import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../providers/theme_provider.dart';
import 'insights_screen.dart';
import 'scanner_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _months = [
    'All',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String searchQuery = '';
  String selectedMonth = 'All';

  Future<void> _refreshExpenses() async {
    ref.read(expenseNotifierProvider.notifier).refresh();
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Widget _chip(String label, bool isDark) {
    final isSelected = selectedMonth == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF145D4A)
                : (isDark ? const Color(0xFFB8C3BE) : const Color(0xFF5F6F69)),
            fontWeight: FontWeight.w600,
          ),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFF1D9E75).withValues(alpha: 0.16),
        backgroundColor: isDark ? const Color(0xFF151A18) : Colors.white,
        side: BorderSide(
          color: isDark ? const Color(0xFF2A3430) : const Color(0xFFE2ECE7),
        ),
        onSelected: (_) => setState(() => selectedMonth = label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allExpenses = ref.watch(expenseNotifierProvider);
    final surfaceColor = isDark ? const Color(0xFF151A18) : Colors.white;
    final subtleSurfaceColor = isDark
        ? const Color(0xFF101513)
        : const Color(0xFFF9FCFB);
    final borderColor = isDark
        ? const Color(0xFF2A3430)
        : const Color(0xFFE3ECE7);
    final secondaryTextColor = isDark
        ? const Color(0xFFB6C2BD)
        : const Color(0xFF6B7B76);

    final expenses = allExpenses.where((expense) {
      final matchesSearch = expense.merchant
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
      final matchesMonth = selectedMonth == 'All' ||
          DateFormat('MMM').format(expense.date) == selectedMonth;
      return matchesSearch && matchesMonth;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final total = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final categoryTotals = <String, double>{};
    for (final expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    final topCategory = categoryTotals.entries.isEmpty
        ? 'General'
        : categoryTotals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final overviewLabel = selectedMonth == 'All'
        ? 'This year at a glance'
        : 'This month at a glance';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Scanner'),
        actions: [
          IconButton(
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshExpenses,
          ),
          IconButton(
            icon: const Icon(Icons.insights),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InsightsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScannerScreen()),
        ),
        backgroundColor: const Color(0xFF1D9E75),
        icon: const Icon(Icons.camera_alt),
        label: const Text('Scan Bill'),
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
          onRefresh: _refreshExpenses,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1D9E75), Color(0xFF155E51)],
                  ),
                  boxShadow: isDark
                      ? const []
                      : const [
                          BoxShadow(
                            color: Color(0x1F1D9E75),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.insights_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '$topCategory focus',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      overviewLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rs ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${expenses.length} expense${expenses.length == 1 ? '' : 's'} in the current view',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by merchant...',
                    prefixIcon: const Icon(Icons.search),
                    fillColor: subtleSurfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => searchQuery = value),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _months.map((month) => _chip(month, isDark)).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Spending mix',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Category distribution for the currently filtered expenses.',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 240,
                      child: categoryTotals.isEmpty
                          ? Center(
                              child: Text(
                                'No chart data yet',
                                style: TextStyle(color: secondaryTextColor),
                              ),
                            )
                          : PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                sections: categoryTotals.entries.map((entry) {
                                  final color = Color(
                                    Expense.categoryColors[entry.key] ??
                                        0xFF9E9E9E,
                                  );
                                  return PieChartSectionData(
                                    color: color,
                                    value: entry.value,
                                    title:
                                        '${entry.key.substring(0, 1)}\nRs ${entry.value.toStringAsFixed(0)}',
                                    radius: 80,
                                    titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Recent expenses',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${expenses.length} items',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (expenses.isEmpty)
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 72,
                              color: Color(0xFFB0BBB6),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No expenses added yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the scan button to add your first bill.',
                              style: TextStyle(color: secondaryTextColor),
                            ),
                          ],
                        ),
                      )
                    else
                      ...expenses.map(
                        (expense) => Dismissible(
                          key: Key(expense.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Delete Expense'),
                                    content: Text('Delete ${expense.merchant}?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(
                                          dialogContext,
                                          false,
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(
                                          dialogContext,
                                          true,
                                        ),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          },
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          onDismissed: (_) async {
                            await ref
                                .read(expenseNotifierProvider.notifier)
                                .deleteExpense(expense.id);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: subtleSurfaceColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Color(
                                    Expense.categoryColors[expense.category] ??
                                        0xFF1D9E75,
                                  ).withValues(alpha: 0.16),
                                  child: Text(
                                    expense.category[0].toUpperCase(),
                                    style: TextStyle(
                                      color: Color(
                                        Expense.categoryColors[expense.category] ??
                                            0xFF1D9E75,
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        expense.merchant,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${expense.category} - ${DateFormat('dd MMM').format(expense.date)}',
                                        style: TextStyle(
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Rs ${expense.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(
                                      Expense.categoryColors[expense.category] ??
                                          0xFF1D9E75,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

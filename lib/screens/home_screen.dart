// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/scanner_screen.dart';
import '../screens/insights_screen.dart';
import '../services/alert_service_new.dart';
import '../widgets/expense_pie_chart.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final months = [
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
    'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    // Watch expense list (already filtered inside ExpenseNotifier)
    final expenses = ref.watch(expenseNotifierProvider);

    // Watch selected filters (kept in sync with notifier when user updates)
    final selectedMonth = ref.watch(selectedMonthProvider);

    // Totals for header and pie chart
    final yearExpenses = ref.watch(selectedYearExpensesProvider);
    final monthExpenses = ref.watch(monthlyExpensesProvider);

    final headerExpenses = selectedMonth == 'All' ? yearExpenses : monthExpenses;
    final headerTotal = headerExpenses.fold<double>(0, (s, e) => s + e.amount);

    // Category totals: if month == All show year totals, else show selected month totals
    final categoryTotals = selectedMonth == 'All'
        ? ref.watch(allCategoryTotalsProvider)
        : ref.watch(categoryTotalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bill Scanner"),
        actions: [
          IconButton(
            icon: Icon(
              ref.watch(themeProvider) == ThemeMode.dark
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: 'Insights',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InsightsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              await ref.read(expenseNotifierProvider.notifier).refresh();
              if (!mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(content: Text('Refreshed')),
              );
            },
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(expenseNotifierProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            /// 🔥 SUMMARY CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D9E75), Color(0xFF146B59)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selectedMonth == 'All' ? 'This Year at a glance' : 'Selected Month at a glance',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                    "₹ ${headerTotal.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${headerExpenses.length} expenses in the current view",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// 🥧 PIE CHART
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Category Breakdown', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (categoryTotals.isNotEmpty)
                      ExpensePieChart(data: categoryTotals)
                    else
                      const Text('No data'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            // Show concise insights at top only when viewing a year (month == 'All')
            if (selectedMonth == 'All')
              Consumer(
                builder: (context, ref, _) {
                  final insights = ref.watch(insightsProvider);
                  if (insights.isEmpty) return const SizedBox.shrink();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Insights', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ...insights.map((i) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('• $i'),
                              )),
                        ],
                      ),
                    ),
                  );
                },
              ),

            /// 🚨 ALERT CHECK BUTTON
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final expenses = ref.read(expenseNotifierProvider);
                    await alertService.checkAllYears(expenses);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Checked all yearly limits! 🚨')),
                      );
                    }
                  },
                  icon: const Icon(Icons.warning, color: Colors.white),
                  label: const Text('Check Yearly Expense Limits'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// 🔍 SEARCH BAR
            TextField(
              onChanged: (value) {
                // Use provider's debounced search
                ref.read(expenseNotifierProvider.notifier).setSearchQuery(value);
              },
              decoration: InputDecoration(
                hintText: "Search merchant or category...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// 📅 YEAR FILTER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Year filter"),
                  Consumer(
                    builder: (ctx, ref, _) {
                      final years = ref.watch(yearOptionsProvider);
                      final val = ref.watch(selectedYearProvider);

                      // Ensure selected value exists in years; if not schedule a safe update
                      final displayVal = years.contains(val) ? val : (years.isNotEmpty ? years.last : DateTime.now().year);
                      if (!years.contains(val)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          // Persist and update providers safely after build
                          ref.read(settingsBoxProvider).put('selectedYear', displayVal);
                          ref.read(selectedYearProvider.notifier).state = displayVal;
                          ref.read(expenseNotifierProvider.notifier).setYear(displayVal);
                        });
                      }

                      return DropdownButton<int>(
                        value: displayVal,
                        items: years
                            .map((y) => DropdownMenuItem(
                                  value: y,
                                  child: Text("$y"),
                                ))
                            .toList(),
                        onChanged: (value) async {
                          if (value == null) return;

                          // persist selection and update providers
                          ref.read(settingsBoxProvider).put('selectedYear', value);
                          ref.read(selectedYearProvider.notifier).state = value;
                          // refresh data first so notifier loads fresh expenses
                          await ref.read(expenseNotifierProvider.notifier).refresh();

                          // then update notifier so filters are applied on fresh data
                          ref.read(expenseNotifierProvider.notifier).setYear(value);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// 📆 MONTH FILTER
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: months.map((m) {
                  final isSelected = m == selectedMonth;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(m),
                      selected: isSelected,
                      onSelected: (_) async {
                        // update both central selectedMonthProvider and notifier
                        ref.read(settingsBoxProvider).put('selectedMonth', m);
                        ref.read(selectedMonthProvider.notifier).state = m;
                        ref.read(expenseNotifierProvider.notifier).setMonth(m);

                        // refresh immediately so UI updates for the selected month
                        await ref.read(expenseNotifierProvider.notifier).refresh();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            /// 📊 EXPENSE LIST
            if (expenses.isEmpty)
              const Center(child: Text("No expenses found")),

            ...expenses.map((e) => Dismissible(
              key: Key(e.id),
              direction: DismissDirection.endToStart,
              background: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerRight,
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                final res = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete expense?'),
                    content: Text('Remove "${e.merchant}"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                    ],
                  ),
                );
                return res ?? false;
              },
              onDismissed: (_) async {
                final deleted = e;
                await ref.read(expenseNotifierProvider.notifier).deleteExpense(e.id);

                if (!mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Expense deleted permanently (local + cloud)'),
                    action: SnackBarAction(
                      label: 'UNDO',
                      onPressed: () async {
                        // restore
                        await ref.read(expenseNotifierProvider.notifier).addExpense(deleted);
                      },
                    ),
                  ),
                );
              },
              child: _buildExpenseTile(e),
            )),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ScannerScreen(),
            ),
          );
        },
        label: const Text("Scan Bill"),
        icon: const Icon(Icons.camera_alt),
      ),
    );
  }

  Widget _buildExpenseTile(Expense e) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(e.category[0]),
        ),
        title: Text(e.merchant),
        subtitle: Text(
          "${e.category} • ${DateFormat('dd MMM').format(e.date)}",
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "₹ ${e.amount.toStringAsFixed(0)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete expense?'),
                    content: Text('Remove "${e.merchant}"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                    ],
                  ),
                );

                if (confirm ?? false) {
                  await ref.read(expenseNotifierProvider.notifier).deleteExpense(e.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/expense.dart';
import '../providers/theme_provider.dart';
import 'scanner_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {

  String searchQuery = '';
  String selectedMonth = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final box = Hive.box<Expense>('expenses');

    List<Expense> expenses = box.values.toList();

    // SEARCH FILTER
    expenses = expenses.where((e) {
      final matchesSearch = e.merchant
          .toLowerCase()
          .contains(searchQuery.toLowerCase());

      final matchesMonth = selectedMonth == 'All'
          ? true
          : DateFormat('MMM').format(e.date) == selectedMonth;

      return matchesSearch && matchesMonth;
    }).toList();

    double total = expenses.fold(0, (sum, e) => sum + e.amount);

    Map<String, double> categoryTotals = {};
    for (var e in expenses) {
      categoryTotals[e.category] =
          (categoryTotals[e.category] ?? 0) + e.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bill Scanner"),
        actions: [

          //  DARK MODE
          IconButton(
            icon: Icon(theme == ThemeMode.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),

          // FIREBASE SYNC BUTTON (UI)
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Syncing to Firebase...")),
              );

              // Hook your Firebase sync here
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScannerScreen()),
          );
        },
        child: const Icon(Icons.camera_alt),
      ),

      body: Column(
        children: [

          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search by merchant...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) {
                setState(() => searchQuery = value);
              },
            ),
          ),

          //  MONTH FILTER
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip("All"),
                ...["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
                    .map(_chip)
              ],
            ),
          ),

          // TOTAL
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              "₹ ${total.toStringAsFixed(2)}",
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),

          //  PIE CHART
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: categoryTotals.entries.map((e) {
                  return PieChartSectionData(
                    value: e.value,
                    title: e.key,
                    radius: 60,
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // LIST + SWIPE DELETE
          Expanded(
            child: expenses.isEmpty
                ? const Center(child: Text("No expenses found"))
                : ListView.builder(
                    itemCount: expenses.length,
                    itemBuilder: (_, i) {
                      final e = expenses[i];

                      return Dismissible(
                        key: Key(e.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          Hive.box<Expense>('expenses').delete(e.id);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Deleted")),
                          );
                        },
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          child: ListTile(
                            title: Text(e.merchant),
                            subtitle: Text(
                              DateFormat('dd MMM yyyy').format(e.date),
                            ),
                            trailing: Text(
                              "₹ ${e.amount.toStringAsFixed(2)}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  //  CHIP WIDGET
  Widget _chip(String label) {
    final selected = selectedMonth == label;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => selectedMonth = label);
        },
      ),
    );
  }
}
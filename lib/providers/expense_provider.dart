import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/expense.dart';

//  Hive Box Provider
final expenseBoxProvider = Provider<Box<Expense>>((ref) {
  return Hive.box<Expense>('expenses');
});

// Expense Notifier
class ExpenseNotifier extends StateNotifier<List<Expense>> {
  final Box<Expense> box;

  ExpenseNotifier(this.box) : super(box.values.toList());

  //  Add Expense
  Future<void> addExpense(Expense expense) async {
    await box.put(expense.id, expense);
    state = box.values.toList();
  }

  //  Delete Expense
  Future<void> deleteExpense(String id) async {
    await box.delete(id);
    state = box.values.toList();
  }

  // Refresh
  void refresh() {
    state = box.values.toList();
  }
}

// Main Provider
final expenseNotifierProvider =
    StateNotifierProvider<ExpenseNotifier, List<Expense>>((ref) {
  final box = ref.watch(expenseBoxProvider);
  return ExpenseNotifier(box);
});


// Monthly Expenses
final monthlyExpensesProvider = Provider<List<Expense>>((ref) {
  final expenses = ref.watch(expenseNotifierProvider);

  final now = DateTime.now();

  return expenses.where((e) =>
      e.date.month == now.month &&
      e.date.year == now.year).toList();
});


//  Total This Month
final monthlyTotalProvider = Provider<double>((ref) {
  final expenses = ref.watch(monthlyExpensesProvider);

  return expenses.fold(0.0, (sum, e) => sum + e.amount);
});


// Category Totals
final categoryTotalsProvider = Provider<Map<String, double>>((ref) {
  final expenses = ref.watch(monthlyExpensesProvider);

  final Map<String, double> totals = {};

  for (var e in expenses) {
    totals[e.category] = (totals[e.category] ?? 0) + e.amount;
  }

  return totals;
});
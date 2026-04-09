import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../services/analytics_service.dart';
import '../services/alert_service_new.dart';
import '../services/firebase_service.dart';
import 'package:logger/logger.dart';

const kYearFilterOptions = [2020, 2021, 2022, 2023, 2024, 2025, 2026];

/// 🟢 Hive Box Provider
final expenseBoxProvider = Provider<Box<Expense>>((ref) {
  return Hive.box<Expense>('expenses');
});

/// Raw expenses list provider (single point to read and cache box values per rebuild)
final rawExpensesProvider = Provider<List<Expense>>((ref) {
  // Use the ExpenseNotifier state as the single source of truth so derived providers
  // (charts, totals, year options) react to changes immediately.
  return ref.watch(expenseNotifierProvider);
});

/// ⚙️ Settings box provider (for persisting UI state)
final settingsBoxProvider = Provider<Box>((ref) {
  return Hive.box('settings');
});

/// 🔄 SORT TYPES
enum SortType { latest, highest, lowest }

/// 🔥 Expense Notifier (UPDATED)
class ExpenseNotifier extends StateNotifier<List<Expense>> {
  static final Logger _logger = Logger();
  final Box<Expense> box;

  ExpenseNotifier(this.box, {int? initialYear, String? initialMonth}) : super(box.values.toList()) {
    _allExpenses = box.values.toList();
    // initialize filter state from persisted values if provided
    _selectedYear = initialYear ?? _selectedYear;
    _selectedMonth = initialMonth ?? _selectedMonth;

    // apply filters so initial state respects persisted year/month
    _applyFilters();
  }

  List<Expense> _allExpenses = [];

  String _searchQuery = "";
  String _selectedCategory = "All";
  int _selectedYear = DateTime.now().year;
  String _selectedMonth = 'All';

  double? _minAmount;
  double? _maxAmount;

  SortType _sortType = SortType.latest;

  Timer? _debounce;

  // Refresh control
  Timer? _refreshTimer;
  Completer<void>? _refreshCompleter;
  bool _isRefreshing = false;

  /// ➕ Add Expense
  Future<void> addExpense(Expense expense) async {
    // persist immediately
    await box.put(expense.id, expense);
    
    // update local cache and UI synchronously so list reflects change instantly
    _allExpenses = box.values.toList();
    _applyFilters();
    
    _logger.i('✅ Saved to Hive: ${expense.merchant} ₹${expense.amount} (ID: ${expense.id})');

    // 🚨 CHECK YEARLY THRESHOLD AND SEND ALERT IF NEEDED
    try {
      final year = expense.date.year;
      // switch UI to the year of the newly added expense so totals/charts reflect it
      setYear(year);
      final yearTotal = _allExpenses.where((e) => e.date.year == year).fold(0.0, (s, e) => s + e.amount);
      _logger.i('Year $year total after save: $yearTotal');
      await alertService.checkYearlyLimit(year: year, totalAmount: yearTotal);
      
      // 🚨 NEW HIGH VALUE PER-TRANSACTION ALERT
      await alertService.checkHighValueAlert(expense);
    } catch (e) {
      _logger.e('addExpense alert error: $e');
    }
  }

  /// ❌ Delete (Local + Firestore sync)
  Future<void> deleteExpense(String id) async {
    await box.delete(id);
    
    // 🔥 SYNC DELETE TO FIRESTORE
    await FirebaseService.deleteExpenseFromFirestore(id);
    
    // refresh UI
    await refresh();
    _logger.i('🗑️ Deleted expense ID: $id (local + Firestore)');
  }

  /// 🔄 Refresh with debounce and guard to avoid UI jank
  Future<void> refresh({int debounceMs = 200}) {
    // Cancel previous timer
    _refreshTimer?.cancel();

    _refreshCompleter ??= Completer<void>();
    _refreshTimer = Timer(Duration(milliseconds: debounceMs), () async {
      if (_isRefreshing) {
        // If already refreshing, complete and return
        _refreshCompleter?.complete();
        _refreshCompleter = null;
        return;
      }

      _isRefreshing = true;
      try {
        // read from box once and apply filters
        _allExpenses = box.values.toList();
        _applyFilters();
      } finally {
        _isRefreshing = false;
        _refreshCompleter?.complete();
        _refreshCompleter = null;
      }
    });

    return _refreshCompleter!.future;
  }

  /// 🔍 SEARCH (DEBOUNCED)
  void setSearchQuery(String query) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchQuery = query.toLowerCase();
      _applyFilters();
    });
  }

  /// 📂 CATEGORY FILTER
  void setCategory(String category) {
    _selectedCategory = category;
    _applyFilters();
  }

  /// 📅 YEAR FILTER
  void setYear(int year) {
    _selectedYear = year;
    _applyFilters();
  }

  /// 📆 MONTH FILTER
  void setMonth(String month) {
    _selectedMonth = month;
    _applyFilters();
  }

  /// 💰 AMOUNT FILTER
  void setAmountRange(double? min, double? max) {
    _minAmount = min;
    _maxAmount = max;
    _applyFilters();
  }

  /// 🔄 SORT
  void setSortType(SortType type) {
    _sortType = type;
    _applyFilters();
  }

  /// 🧠 CORE FILTER LOGIC
  void _applyFilters() {
    List<Expense> filtered = _allExpenses.where((e) {
      final matchesSearch =
          e.merchant.toLowerCase().contains(_searchQuery) ||
          e.category.toLowerCase().contains(_searchQuery);

      final matchesCategory =
          _selectedCategory == "All" || e.category == _selectedCategory;

      final matchesYear = e.date.year == _selectedYear;

      final matchesMonth = _selectedMonth == 'All' ||
          (DateFormat('MMM').format(e.date) == _selectedMonth);

      final matchesMin =
          _minAmount == null || e.amount >= _minAmount!;

      final matchesMax =
          _maxAmount == null || e.amount <= _maxAmount!;

      return matchesSearch &&
          matchesCategory &&
          matchesYear &&
          matchesMonth &&
          matchesMin &&
          matchesMax;
    }).toList();

    /// 🔄 SORTING
    if (_sortType == SortType.latest) {
      filtered.sort((a, b) => b.date.compareTo(a.date));
    } else if (_sortType == SortType.highest) {
      filtered.sort((a, b) => b.amount.compareTo(a.amount));
    } else {
      filtered.sort((a, b) => a.amount.compareTo(b.amount));
    }

    state = filtered;
  }
}

/// 🟢 MAIN PROVIDER
final StateNotifierProvider<ExpenseNotifier, List<Expense>> expenseNotifierProvider =
    StateNotifierProvider<ExpenseNotifier, List<Expense>>((ref) {
  final box = ref.watch(expenseBoxProvider);
  final settings = ref.watch(settingsBoxProvider);
  final savedYear = settings.get('selectedYear');
  final savedMonth = settings.get('selectedMonth');

  final initYear = savedYear is int ? savedYear : DateTime.now().year;
  final initMonth = savedMonth is String ? savedMonth : 'All';

  return ExpenseNotifier(box, initialYear: initYear, initialMonth: initMonth);
});

/// 📊 Generate dynamic year options from stored expenses
final yearOptionsProvider = Provider<List<int>>((ref) {
  final all = ref.watch(rawExpensesProvider);
  final yearsFromData = all.map((e) => e.date.year).toSet();

  // Ensure the static range is always available (2020-2026) plus any years present in data
  final combined = <int>{...kYearFilterOptions, ...yearsFromData};
  final years = combined.toList()..sort();
  return years;
});

/// 📅 YEAR FILTER STATE (persisted in settings)
final selectedYearProvider = StateProvider<int>((ref) {
  final settings = ref.watch(settingsBoxProvider);
  final saved = settings.get('selectedYear');
  if (saved is int) return saved;

  final currentYear = DateTime.now().year;
  final options = ref.read(yearOptionsProvider);
  if (options.contains(currentYear)) return currentYear;
  return options.isNotEmpty ? options.last : currentYear;
});

/// 📆 MONTH FILTER STATE (persisted)
final selectedMonthProvider = StateProvider<String>((ref) {
  final settings = ref.watch(settingsBoxProvider);
  final saved = settings.get('selectedMonth');
  if (saved is String) return saved;
  return 'All';
});

/// 📆 FILTERED EXPENSES BASED ON SELECTED YEAR & MONTH
final monthlyExpensesProvider = Provider<List<Expense>>((ref) {
  final expenses = ref.watch(rawExpensesProvider);
  final selectedYear = ref.watch(selectedYearProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);

  if (selectedMonth == 'All') {
    return expenses.where((e) => e.date.year == selectedYear).toList();
  }

  // Convert 'Jan'.. to month index
  final monthIndex = DateFormat('MMM').parse(selectedMonth).month;

  return expenses
      .where((e) => e.date.year == selectedYear && e.date.month == monthIndex)
      .toList();
});

/// 📅 YEAR EXPENSES
final selectedYearExpensesProvider = Provider<List<Expense>>((ref) {
  final expenses = ref.watch(rawExpensesProvider);
  final selectedYear = ref.watch(selectedYearProvider);

  return expenses.where((e) => e.date.year == selectedYear).toList();
});

/// 💰 TOTAL THIS MONTH / SELECTED MONTH
final monthlyTotalProvider = Provider<double>((ref) {
  final expenses = ref.watch(monthlyExpensesProvider);
  return expenses.fold(0.0, (sum, e) => sum + e.amount);
});

/// 📊 Monthly totals for the selected year (1..12)
final monthlyTotalsOfYearProvider = Provider<Map<int, double>>((ref) {
  final year = ref.watch(selectedYearProvider);
  final expenses = ref.watch(rawExpensesProvider);
  final Map<int, double> totals = {for (int m = 1; m <= 12; m++) m: 0.0};

  for (final e in expenses) {
    if (e.date.year == year) {
      totals[e.date.month] = (totals[e.date.month] ?? 0) + e.amount;
    }
  }

  return totals;
});

/// 📊 CATEGORY TOTALS (FOR SELECTED MONTH OR YEAR)
final categoryTotalsProvider = Provider<Map<String, double>>((ref) {
  final expenses = ref.watch(monthlyExpensesProvider);
  final Map<String, double> totals = {};

  for (final e in expenses) {
    totals[e.category] = (totals[e.category] ?? 0) + e.amount;
  }

  return totals;
});

/// 📊 CATEGORY TOTALS (YEAR)
final allCategoryTotalsProvider = Provider<Map<String, double>>((ref) {
  final expenses = ref.watch(selectedYearExpensesProvider);
  final Map<String, double> totals = {};

  for (final expense in expenses) {
    totals[expense.category] =
        (totals[expense.category] ?? 0) + expense.amount;
  }

  return totals;
});

/// 🧠 INSIGHTS (respect selected month if set)
final insightsProvider = Provider<List<String>>((ref) {
  final selectedMonth = ref.watch(selectedMonthProvider);
  final expenses = selectedMonth == 'All'
      ? ref.watch(selectedYearExpensesProvider)
      : ref.watch(monthlyExpensesProvider);

  return AnalyticsService.generateInsights(expenses);
});

/// 📈 TRENDS
final trendsProvider = Provider<Map<String, double>>((ref) {
  final expenses = ref.watch(expenseNotifierProvider);
  final now = DateTime.now();
  final previousMonth = DateTime(now.year, now.month - 1);

  final currMonthTotal = ref.watch(monthlyTotalProvider);

  final lastMonthExpenses = expenses
      .where(
        (e) =>
            e.date.month == previousMonth.month &&
            e.date.year == previousMonth.year,
      )
      .fold(0.0, (sum, e) => sum + e.amount);

  final trend = lastMonthExpenses > 0
      ? ((currMonthTotal - lastMonthExpenses) /
          lastMonthExpenses *
          100)
      : 0.0;

  return {'overall': trend};
});

/// 🔍 DUPLICATE CHECK
final duplicateCheckProvider = Provider.family<double, Expense>((ref, newExp) {
  final expenses = ref.watch(expenseNotifierProvider);
  return AnalyticsService.duplicateScore(newExp, expenses);
});
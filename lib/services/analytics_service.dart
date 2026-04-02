
import '../models/expense.dart';

class AnalyticsService {
  static List<String> generateInsights(List<Expense> expenses) {
    if (expenses.isEmpty) return [];

    final now = DateTime.now();
    final startOfCurrentMonth = DateTime(now.year, now.month);
    final lastMonth =
        DateTime(startOfCurrentMonth.year, startOfCurrentMonth.month - 1);

    final thisMonth = expenses.where((e) => 
        e.date.month == now.month && e.date.year == now.year).toList();
    final prevMonth = expenses.where((e) => 
        e.date.month == lastMonth.month && e.date.year == lastMonth.year).toList();

    final insights = <String>[];

    // Total trend
    final currTotal = _categoryTotal(thisMonth, 'All');
    final prevTotal = _categoryTotal(prevMonth, 'All');
    if (prevTotal > 0) {
      final change = ((currTotal - prevTotal) / prevTotal * 100).round();
      insights.add(
        'Monthly spending ${change > 0 ? 'up' : 'down'} ${change.abs()}% (${_formatMoney(currTotal)})',
      );
    }

    // Category trends
    final cats = _categoryTotals(thisMonth);
    final prevCats = _categoryTotals(prevMonth);
    cats.forEach((cat, amt) {
      final prevAmt = prevCats[cat] ?? 0;
      if (prevAmt > 10) { // significant
        final change = ((amt - prevAmt) / prevAmt * 100).round();
        if (change.abs() > 20) {
          insights.add('$cat spending ${change > 0 ? 'up' : 'down'} ${change.abs()}%');
        }
      }
    });

    // Recurring vendors
    final recurring = detectRecurring(expenses);
    if (recurring.isNotEmpty) {
      insights.add('Recurring: ${recurring.join(', ')}');
    }

    return insights.take(3).toList(); // top 3
  }

  static Map<String, double> _categoryTotals(List<Expense> expenses) {
    final totals = <String, double>{};
    for (var e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    return totals;
  }

  static double _categoryTotal(List<Expense> expenses, String category) {
    return expenses
        .where((e) => category == 'All' || e.category == category)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  static String _formatMoney(double amt) => '₹${amt.toStringAsFixed(0)}';

  static List<String> detectRecurring(List<Expense> expenses) {
    final vendors = <String, List<Expense>>{};
    for (var e in expenses) {
      vendors[e.merchant] = [...?vendors[e.merchant], e];
    }
    return vendors.entries
        .where((e) => e.value.length >= 2)
        .map((e) => e.key)
        .take(3)
        .toList();
  }

  // Duplicate score 0-1
  static double duplicateScore(Expense newExp, List<Expense> existing) {
    for (var e in existing) {
      if ((newExp.merchant.toLowerCase().contains(e.merchant.toLowerCase()) ||
           e.merchant.toLowerCase().contains(newExp.merchant.toLowerCase())) &&
          (newExp.date.difference(e.date).inDays.abs() < 7) &&
          (newExp.amount - e.amount).abs() / newExp.amount < 0.1) {
        return 0.9; // high dupe
      }
    }
    return 0.0;
  }

  // Prediction: expected recurring
  static Map<String, DateTime?> predictNext(Expense exp, List<Expense> history) {
    final sameVendor = history.where((e) => e.merchant == exp.merchant).toList();
    if (sameVendor.length >= 2) {
      sameVendor.sort((a, b) => b.date.compareTo(a.date));
      final interval = sameVendor[0].date.difference(sameVendor[1].date).inDays;
      return {exp.merchant: DateTime.now().add(Duration(days: interval))};
    }
    return {};
  }
}


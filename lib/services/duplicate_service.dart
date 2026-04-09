import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/expense.dart';

class DuplicateService {
  /// 🔥 Threshold for duplicate detection
  static const double threshold = 0.75;

  /// ✅ MAIN CHECK → returns TRUE if duplicate
  static Future<bool> isDuplicate(Expense newExpense) async {
    final box = Hive.box<Expense>('expenses');

    for (final existing in box.values) {
      final score = _calculateSimilarity(existing, newExpense);

      if (score >= threshold) {
        return true;
      }
    }

    return false;
  }

  /// 🔍 GET BEST MATCH SCORE (for UI display)
  static Future<double> duplicateScore(Expense newExpense) async {
    final box = Hive.box<Expense>('expenses');

    double maxScore = 0.0;

    for (final existing in box.values) {
      final score = _calculateSimilarity(existing, newExpense);
      if (score > maxScore) maxScore = score;
    }

    return maxScore;
  }

  /// 🧠 CORE AI SIMILARITY ENGINE
  static double _calculateSimilarity(Expense a, Expense b) {
    double score = 0.0;

    /// 🔥 1. SAME FILE (VERY STRONG SIGNAL)
    if (a.imagePath == b.imagePath) {
      return 1.0;
    }

    /// 🔤 2. MERCHANT SIMILARITY (30%)
    final merchantScore = _stringSimilarity(
      a.merchant.toLowerCase(),
      b.merchant.toLowerCase(),
    );
    score += merchantScore * 0.3;

    /// 💰 3. AMOUNT SIMILARITY (30%)
    final amountDiff = (a.amount - b.amount).abs();
    double amountScore;

    if (amountDiff < 1) {
      amountScore = 1.0;
    } else {
      amountScore = max(0, 1 - (amountDiff / max(a.amount, b.amount)));
    }
    score += amountScore * 0.3;

    /// 📅 4. DATE SIMILARITY (20%)
    final dateDiff = a.date.difference(b.date).inDays.abs();
    double dateScore;

    if (dateDiff == 0) {
      dateScore = 1.0;
    } else if (dateDiff <= 2) {
      dateScore = 0.7;
    } else if (dateDiff <= 7) {
      dateScore = 0.4;
    } else {
      dateScore = 0.0;
    }
    score += dateScore * 0.2;

    /// 📂 5. CATEGORY MATCH (20%)
    final categoryScore =
        a.category.toLowerCase() == b.category.toLowerCase() ? 1.0 : 0.0;
    score += categoryScore * 0.2;

    return score;
  }

  /// 🔤 SIMPLE WORD-BASED STRING SIMILARITY
  static double _stringSimilarity(String a, String b) {
    if (a == b) return 1.0;

    final aWords = a.split(RegExp(r'\s+'));
    final bWords = b.split(RegExp(r'\s+'));

    int matchCount = 0;

    for (final word in aWords) {
      if (bWords.contains(word)) {
        matchCount++;
      }
    }

    return matchCount / max(aWords.length, bWords.length);
  }
}
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

import '../models/expense.dart';

class DuplicateService {
  static Future<bool> isDuplicate(Expense newExpense) async {
    final box = Hive.box<Expense>('expenses');
    final newFingerprint = await _fileFingerprint(newExpense.imagePath);

    for (final existing in box.values) {
      final amountClose = (existing.amount - newExpense.amount).abs() < 0.01;
      final dateClose = existing.date
              .difference(newExpense.date)
              .inDays
              .abs() <=
          1;

      if (amountClose && dateClose) {
        return true;
      }

      if (newFingerprint == null || newFingerprint.isEmpty) {
        continue;
      }

      final existingFingerprint = await _fileFingerprint(existing.imagePath);
      if (existingFingerprint == null || existingFingerprint.isEmpty) {
        continue;
      }

      if (existingFingerprint == newFingerprint) {
        return true;
      }
    }

    return false;
  }

  static Future<String?> _fileFingerprint(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      return sha1.convert(bytes).toString();
    } catch (_) {
      return null;
    }
  }
}

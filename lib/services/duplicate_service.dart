import 'package:hive/hive.dart';
import '../models/expense.dart';

class DuplicateService {
  static bool isDuplicate(Expense newExpense) {
    final box = Hive.box<Expense>('expenses');

    return box.values.any((e) =>
        e.amount == newExpense.amount &&
        e.merchant == newExpense.merchant &&
        e.date.difference(newExpense.date).inDays.abs() <= 1);
  }
}
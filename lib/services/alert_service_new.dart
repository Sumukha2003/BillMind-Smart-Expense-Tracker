import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';
import 'email_service.dart';
import 'notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';

class AlertServiceNew {
  final EmailService emailService = EmailService();

  static const double yearlyLimit = 100000;

  Future<void> init() async {
    await NotificationService.init();
  }

  Future<void> checkYearlyLimit({
    required int year,
    required double totalAmount,
    bool force = false,
  }) async {
    if (kDebugMode) debugPrint('[AlertService] Year: $year | Total: ₹$totalAmount');

    if (totalAmount < yearlyLimit) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> alertedYears = prefs.getStringList('alerted_years') ?? [];

    if (!force && alertedYears.contains(year.toString())) {
      if (kDebugMode) debugPrint('[AlertService] Already alerted for $year');
      return;
    }

    const subject = '🚨 Yearly Expense Limit Exceeded';
    final body =
        'Your total expenses for $year have exceeded ₹1,00,000.\n'
        'Current total: ₹$totalAmount.\n'
        'Please review your spending.';

    bool success = false;

    for (int i = 0; i < 3; i++) {
      final recipient = dotenv.env['ALERT_RECIPIENT'];
      if (kDebugMode) debugPrint('[AlertServiceNew] Sending to: $recipient (attempt ${i + 1})');
      success = await emailService.sendEmail(
        subject: subject,
        body: body,
      );
      if (success) break;
      if (i < 2) await Future.delayed(const Duration(seconds: 2));
    }

    if (!success) {
      if (kDebugMode) debugPrint('[AlertService] Email failed → showing notification');
      await NotificationService.show(subject, body);
    }

    if (!force) {
      alertedYears.add(year.toString());
      await prefs.setStringList('alerted_years', alertedYears);
    }
  }

  /// Check all years for alerts (manual button)
  Future<void> checkAllYears(List<Expense> expenses) async {
    final yearTotals = <int, double>{};
    for (final expense in expenses) {
      final year = expense.date.year;
      yearTotals[year] = (yearTotals[year] ?? 0) + expense.amount;
    }

    if (kDebugMode) debugPrint('[AlertService] Manual check: ${yearTotals.length} years');
    for (final entry in yearTotals.entries) {
      await checkYearlyLimit(year: entry.key, totalAmount: entry.value, force: true);
    }
  }

  /// 🚨 HIGH VALUE TRANSACTION ALERT (> ₹1,00,000)
  Future<void> checkHighValueAlert(Expense expense) async {
    final year = expense.date.year;
    if (year < 2020 || year > 2026) return;

    if (kDebugMode) debugPrint('[AlertService] High value check: amount=${expense.amount}, sent=${expense.highValueAlertSent}');
    if (expense.amount <= 100000 || expense.highValueAlertSent) {
      return;
    }

    const subject = '🚨 HIGH VALUE TRANSACTION DETECTED';
    final body = '''
High value expense detected!

Merchant: ${expense.merchant}
Amount: ₹${expense.amount.toStringAsFixed(0)}
Date: ${DateFormat('dd MMM yyyy').format(expense.date)}
Category: ${expense.category}
Image: ${expense.imagePath}

Review this transaction immediately.
    ''';

    bool success = false;
    for (int i = 0; i < 3; i++) {
      final recipient = dotenv.env['ALERT_RECIPIENT'];
      if (kDebugMode) debugPrint('[AlertServiceNew] High value to: $recipient (attempt ${i + 1})');
      success = await emailService.sendEmail(
        subject: subject,
        body: body,
      );
      if (success) break;
      if (i < 2) await Future.delayed(const Duration(seconds: 2));
    }

    if (!success) {
      if (kDebugMode) debugPrint('[AlertService] High value email failed → notification');
      await NotificationService.show(subject, body);
    }

    expense.highValueAlertSent = true;
    await expense.save();

    if (kDebugMode) debugPrint('[AlertService] High value alert sent for ${expense.id}');
  }
}

final alertService = AlertServiceNew();


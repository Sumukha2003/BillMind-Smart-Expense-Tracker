// Deprecated shim for older AlertService API.
// This file now delegates to the new AlertServiceNew implementation (alertService).
// Kept for backwards compatibility so older callers keep working while we migrate.

import 'alert_service_new.dart' show alertService;

class AlertService {
  /// Deprecated: delegates to AlertServiceNew.checkYearlyLimit
  static Future<void> checkAndSendYearlyAlert(int year, double total) async {
    await alertService.checkYearlyLimit(year: year, totalAmount: total);
  }

  /// Deprecated: kept for compatibility
  static Future<void> sendThresholdAlert(int year, double total) async {
    await alertService.checkYearlyLimit(year: year, totalAmount: total);
  }
}

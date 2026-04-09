import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  Future<bool> sendEmail({
    required String subject,
    required String body,
  }) async {
    try {
      final smtpHost = dotenv.env['SMTP_HOST'];
      final smtpPortStr = dotenv.env['SMTP_PORT'];
      final username = dotenv.env['SMTP_USER'];
      final password = dotenv.env['SMTP_PASS'];
      final recipient = dotenv.env['ALERT_RECIPIENT'];

      if (smtpHost == null || smtpPortStr == null || username == null || password == null || recipient == null) {
        if (kDebugMode) {
          debugPrint('[EmailService] ERROR: Missing .env vars. Required: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, ALERT_RECIPIENT');
          debugPrint('[EmailService] Available keys: ${dotenv.env.keys.join(', ')}');
        }
        return false;
      }

      final smtpServer = SmtpServer(
        smtpHost,
        port: int.parse(smtpPortStr),
        username: username,
        password: password,
      );

      final message = Message()
        ..from = Address(username, 'Expense Tracker')
        ..recipients.add(recipient)
        ..subject = subject
        ..text = body;

      if (kDebugMode) debugPrint('[EmailService] Sending email...');

      final sendReport = await send(message, smtpServer);

      if (kDebugMode) debugPrint('[EmailService] Email sent: $sendReport');
      return true;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[EmailService] Send failed: $e');
        debugPrint('[EmailService] Check SMTP config in .env (Gmail needs App Password)');
        debugPrint('[EmailService] Stack: $stack');
      }
      return false;
    }
  }

  static Future<void> init() async {
    // Early validation
    final vars = ['SMTP_HOST', 'SMTP_PORT', 'SMTP_USER', 'SMTP_PASS', 'ALERT_RECIPIENT'];
    final missing = vars.where((v) => dotenv.env[v] == null).toList();
    if (missing.isNotEmpty && kDebugMode) {
      debugPrint('[EmailService.init] Missing .env vars: $missing');
      debugPrint('[EmailService.init] Copy .env.example to .env and configure!');
    }
  }
}


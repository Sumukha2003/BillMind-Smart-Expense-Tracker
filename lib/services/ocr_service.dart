import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';

class OCRService {
  static Future<String> extractText(File file) async {
    final inputImage = InputImage.fromFile(file);
    final textRecognizer = TextRecognizer();

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text.trim();
    } finally {
      await textRecognizer.close();
    }
  }

  static Future<Map<String, dynamic>> processBill(File file) async {
    final text = await extractText(file);
    final merchant = extractMerchant(text);

    return {
      'text': text,
      'amount': extractAmount(text),
      'date': extractDate(text),
      'merchant': merchant,
      'category': detectCategory(merchant),
    };
  }

  static double extractAmount(String text) {
    final regex = RegExp(r'(\d+[.,]?\d{0,2})');
    final matches = regex.allMatches(text);

    double maxAmount = 0;

    for (final match in matches) {
      final value = double.tryParse(match.group(0)!.replaceAll(',', ''));
      if (value != null && value > maxAmount) {
        maxAmount = value;
      }
    }

    return maxAmount;
  }

  static DateTime extractDate(String text) {
    final regex = RegExp(r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b');
    final match = regex.firstMatch(text);

    if (match != null) {
      final raw = match.group(0)!;

      try {
        return DateTime.parse(raw);
      } catch (_) {}

      const formats = [
        'dd/MM/yyyy',
        'dd-MM-yyyy',
        'dd/MM/yy',
        'dd-MM-yy',
        'MM/dd/yyyy',
        'MM-dd-yyyy',
      ];

      for (final format in formats) {
        try {
          return DateFormat(format).parseLoose(raw);
        } catch (_) {}
      }
    }

    return DateTime.now();
  }

  static String extractMerchant(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return lines.isNotEmpty ? lines.first : 'Unknown';
  }

  static String detectCategory(String merchant) {
    final normalized = merchant.toLowerCase();

    if (normalized.contains('restaurant') || normalized.contains('hotel')) {
      return 'Food';
    }
    if (normalized.contains('uber') || normalized.contains('ola')) {
      return 'Travel';
    }
    if (normalized.contains('mart') || normalized.contains('store')) {
      return 'Grocery';
    }

    return 'General';
  }
}

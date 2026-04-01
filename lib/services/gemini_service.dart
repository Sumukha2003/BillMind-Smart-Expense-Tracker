import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
  }

  Future<Map<String, dynamic>> parseBill(String rawText) async {
    final cleaned = rawText;

    //  RULE ENGINE FIRST
    final amount = _extractTotal(cleaned);
    final merchant = _extractMerchant(cleaned);
    final date = _extractDate(cleaned);
    final category = _detectCategory(cleaned);

    try {
      final response = await _model.generateContent([
        Content.text(_prompt(cleaned)),
      ]);

      final text = response.text ?? '{}';

      final parsed = json.decode(
        text.replaceAll('```json', '').replaceAll('```', ''),
      );

      return {
        'merchant': parsed['merchant'] ?? merchant,
        'amount': (parsed['amount'] ?? amount).toDouble(),
        'date': parsed['date'] ?? date,
        'category': parsed['category'] ?? category,
        'items': parsed['items'] ?? [],
        'cgst': (parsed['cgst'] ?? 0).toDouble(),
        'sgst': (parsed['sgst'] ?? 0).toDouble(),
        'gst_number': parsed['gst_number'],
      };
    } catch (_) {
      return {
        'merchant': merchant,
        'amount': amount,
        'date': date,
        'category': category,
        'items': [],
        'cgst': 0.0,
        'sgst': 0.0,
        'gst_number': null,
      };
    }
  }

  //  SMART PROMPT
  String _prompt(String text) => '''
Extract bill info as JSON.

Focus on FINAL TOTAL only.

$text
''';

  //  STRONG TOTAL DETECTION
  double _extractTotal(String text) {
    final lines = text.split('\n');

    for (var line in lines.reversed) {
      final lower = line.toLowerCase();

      if (lower.contains('total') ||
          lower.contains('grand') ||
          lower.contains('amount')) {
        final match =
            RegExp(r'\d{1,3}(,\d{3})*(\.\d{2})?').firstMatch(line);

        if (match != null) {
          return double.parse(match.group(0)!.replaceAll(',', ''));
        }
      }
    }

    // fallback: max value
    final values = RegExp(r'\d{1,3}(,\d{3})*(\.\d{2})?')
        .allMatches(text)
        .map((e) => double.parse(e.group(0)!.replaceAll(',', '')))
        .toList();

    if (values.isEmpty) return 0;
    values.sort();
    return values.last;
  }

  // MERCHANT DETECTION
  String _extractMerchant(String text) {
    final lines = text.split('\n');

    for (var line in lines.take(5)) {
      if (!line.contains(RegExp(r'\d')) && line.length > 5) {
        return line.trim();
      }
    }

    return "Unknown";
  }

  //  DATE DETECTION
  String _extractDate(String text) {
    final match = RegExp(
      r'\d{2}[-/]\d{2}[-/]\d{4}',
    ).firstMatch(text);

    return match?.group(0) ??
        DateTime.now().toIso8601String().split('T')[0];
  }

  // CATEGORY
  String _detectCategory(String text) {
    final t = text.toLowerCase();

    if (t.contains('restaurant') || t.contains('food')) return 'Food';
    if (t.contains('grocery') || t.contains('mart')) return 'Grocery';
    if (t.contains('medical') || t.contains('pharma')) return 'Medical';

    if (t.contains('fee') ||
        t.contains('college') ||
        t.contains('university')) {
      return 'Education';
    }

    return 'Other';
  }
}
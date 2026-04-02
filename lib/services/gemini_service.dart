import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
  }

  Future<Map<String, dynamic>> parseBill(String rawText) async {
    final cleaned = rawText.trim();

    // ENHANCED RULE ENGINE
    final amount = _extractTotal(cleaned);
    final merchant = _extractMerchant(cleaned);
    final dateStr = _extractDate(cleaned);
    final catScores = _detectCategories(cleaned);
    final category = _getBestCategory(catScores);
    final gstNumber = _extractGstNumber(cleaned);
    final cgst = _extractTax(cleaned, 'CGST');
    final sgst = _extractTax(cleaned, 'SGST');
    final hash = _generateHash(merchant, dateStr, amount);

    try {
      final response = await _model.generateContent([
        Content.text(_prompt(cleaned)),
      ]);

      final text = response.text ?? '{}';
      final parsed = json.decode(
        text.replaceAll('```json', '').replaceAll('```', '').trim(),
      );

      return {
        'merchant': parsed['merchant'] ?? merchant,
        'amount': _asDouble(parsed['amount'], amount),
        'date': parsed['date'] ?? dateStr,
        'category': parsed['category'] ?? category,
        'items': parsed['items'] ?? [],
        'cgst': _asDouble(parsed['cgst'], cgst),
        'sgst': _asDouble(parsed['sgst'], sgst),
        'gst_number': parsed['gst_number'] ?? gstNumber,
        'hash': hash,
        'subtotal': _asDouble(parsed['amount'], amount) -
            (_asDouble(parsed['cgst'], cgst) + _asDouble(parsed['sgst'], sgst)),
        'tax_percent': amount > 0
            ? (((cgst + sgst) / amount) * 100).clamp(0.0, 100.0)
            : 0.0,
      };
    } catch (e) {
      return {
        'merchant': merchant,
        'amount': amount,
        'date': dateStr,
        'category': category,
        'items': [],
        'cgst': cgst,
        'sgst': sgst,
        'gst_number': gstNumber,
        'hash': hash,
        'subtotal': amount - (cgst + sgst),
        'tax_percent':
            amount > 0 ? ((cgst + sgst) / amount * 100).clamp(0.0, 100.0) : 0.0,
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

    return 'Unknown';
  }

  //  DATE DETECTION
  String _extractDate(String text) {
    final match = RegExp(
      r'\d{2}[-/]\d{2}[-/]\d{4}',
    ).firstMatch(text);

    return match?.group(0) ??
        DateTime.now().toIso8601String().split('T')[0];
  }

  // ADVANCED GST DETECTION
  String? _extractGstNumber(String text) {
    final gstMatch = RegExp(
      r'\b[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\b',
    ).firstMatch(text);
    return gstMatch?.group(0);
  }

  double _extractTax(String text, String taxType) {
    final lines = text.split('\n');
    for (var line in lines.reversed) {
      final lower = line.toLowerCase();
      if (lower.contains(taxType.toLowerCase()) && lower.contains('@')) {
        final amtMatch = RegExp(r'\d{1,3}(,\d{3})*(\.\d{2})?').firstMatch(line);
        if (amtMatch != null) {
          return double.parse(amtMatch.group(0)!.replaceAll(',', ''));
        }
      }
    }
    return 0.0;
  }

  // IMPROVED CATEGORY - SCORE BASED
  Map<String, double> _detectCategories(String text) {
    final t = text.toLowerCase();
    final scores = <String, double>{};

    // Food
    int foodScore = 0;
    const foodKeywords = [
      'restaurant',
      'food',
      'cafe',
      'dining',
      'zomato',
      'swiggy',
    ];
    for (final kw in foodKeywords) {
      if (t.contains(kw)) {
        foodScore++;
      }
    }
    if (foodScore > 0) scores['Food'] = foodScore.toDouble();

    // Grocery
    int groceryScore = 0;
    const groceryKeywords = [
      'grocery',
      'mart',
      'kirana',
      'bigbasket',
      'blinkit',
    ];
    for (final kw in groceryKeywords) {
      if (t.contains(kw)) {
        groceryScore++;
      }
    }
    if (groceryScore > 0) scores['Grocery'] = groceryScore.toDouble();

    // Transport
    if (t.contains('uber') ||
        t.contains('ola') ||
        t.contains('taxi') ||
        t.contains('auto')) {
      scores['Transport'] = 1.0;
    }

    // Utility
    if (t.contains('electricity') ||
        t.contains('water') ||
        t.contains('gas')) {
      scores['Utility'] = 1.0;
    }

    // Medical
    int medScore = 0;
    const medKeywords = [
      'medical',
      'pharma',
      'hospital',
      'clinic',
      'medicine',
    ];
    for (final kw in medKeywords) {
      if (t.contains(kw)) {
        medScore++;
      }
    }
    if (medScore > 0) scores['Medical'] = medScore.toDouble();

    // Shopping
    if (t.contains('amazon') ||
        t.contains('flipkart') ||
        t.contains('myntra')) {
      scores['Shopping'] = 1.0;
    }

    // Education
    if (t.contains('fee') ||
        t.contains('college') ||
        t.contains('university') ||
        t.contains('school')) {
      scores['Education'] = 1.0;
    }

    if (scores.isEmpty) scores['Other'] = 1.0;
    final maxScore = scores.values.reduce((a, b) => a > b ? a : b);
    return scores.map((k, v) => MapEntry(k, v / maxScore));
  }

  String _getBestCategory(Map<String, double> scores) {
    if (scores.isEmpty) return 'Other';
    return scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  // DUPE/RECURRING HASH
  String _generateHash(String merchant, String date, double amount) {
    final parsedDate = _parseReceiptDate(date) ?? DateTime.now();
    final normalized =
        '${merchant.toLowerCase()}-${DateFormat('yyyy-MM-dd').format(parsedDate)}-${amount.toStringAsFixed(0)}';
    return normalized.hashCode.toString();
  }

  DateTime? _parseReceiptDate(String date) {
    final direct = DateTime.tryParse(date);
    if (direct != null) return direct;

    const formats = [
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'dd/MM/yy',
      'dd-MM-yy',
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parseStrict(date);
      } catch (_) {}
    }

    return null;
  }
}

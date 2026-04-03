import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

import 'ocr_service.dart';

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
    final merchant = OCRService.extractMerchant(cleaned);
    final date = OCRService.extractDate(cleaned);
    final dateStr = date != null ? DateFormat('yyyy-MM-dd').format(date) : null;
    final category = OCRService.detectCategory(merchant, text: cleaned);
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
    return OCRService.extractAmountDetails(text).amount;
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

  double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  // DUPE/RECURRING HASH
  String _generateHash(String merchant, String? date, double amount) {
    final parsedDate = date == null ? null : _parseReceiptDate(date);
    final dateKey = parsedDate == null
        ? 'unknown-date'
        : DateFormat('yyyy-MM-dd').format(parsedDate);
    final normalized =
        '${merchant.toLowerCase()}-$dateKey-${amount.toStringAsFixed(0)}';
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

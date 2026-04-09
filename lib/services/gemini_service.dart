import 'dart:convert';

import 'package:flutter/foundation.dart';
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

    // ENHANCED RULE ENGINE - OFFLINE FIRST
    final amount = _extractTotal(cleaned);
    final merchant = OCRService.extractMerchant(cleaned);
    final date = OCRService.extractDate(cleaned);
    final dateStr = date != null ? DateFormat('yyyy-MM-dd').format(date) : null;
    final category = OCRService.detectCategory(merchant, text: cleaned);
    final gstNumber = _extractGstNumber(cleaned);
    
    // ✅ FIXED: Full GST breakdown extraction
    final gstBreakdown = _extractGstBreakdown(cleaned);
    final hash = _generateHash(merchant, dateStr, amount);

    // Return complete result immediately (offline-first)
    final result = {
      'merchant': merchant,
      'amount': amount,
      'date': dateStr,
      'category': category,
      'items': [],
      'gst_number': gstNumber,
      'hash': hash,
      'gstBreakdown': gstBreakdown,  // ✅ COMPLETE BREAKDOWN
    };

    try {
      final response = await _model.generateContent([
        Content.text(_prompt(cleaned)),
      ]).timeout(const Duration(seconds: 10));

      final text = response.text ?? '{}';
      final parsed = json.decode(
        text.replaceAll('```json', '').replaceAll('```', '').trim(),
      );

      // Merge AI with offline (AI fallback for edge cases)
      result['merchant'] = parsed['merchant'] ?? merchant;
      result['amount'] = _asDouble(parsed['amount'], amount);
      result['date'] = parsed['date'] ?? dateStr;
      result['category'] = parsed['category'] ?? category;
      result['items'] = parsed['items'] ?? [];
      
      // ✅ AI-enhanced GST (with offline fallback)
      final aiGstBreakdown = {
        'cgst': _asDouble(parsed['cgst'], gstBreakdown['cgst'] ?? 0.0),
        'sgst': _asDouble(parsed['sgst'], gstBreakdown['sgst'] ?? 0.0),
        'igst': _asDouble(parsed['igst'], gstBreakdown['igst'] ?? 0.0),
        'subtotal': _asDouble(parsed['subtotal'], amount - ((gstBreakdown['cgst'] ?? 0.0) + (gstBreakdown['sgst'] ?? 0.0) + (gstBreakdown['igst'] ?? 0.0))),
        'tax_percent': amount > 0 ? 
            (((_asDouble(parsed['cgst'], gstBreakdown['cgst'] ?? 0.0) + 
               _asDouble(parsed['sgst'], gstBreakdown['sgst'] ?? 0.0) + 
               _asDouble(parsed['igst'], gstBreakdown['igst'] ?? 0.0)) / amount) * 100).clamp(0.0, 100.0) : 0.0,
      };
      result['gstBreakdown'] = aiGstBreakdown;
      
      result['gst_number'] = parsed['gst_number'] ?? gstNumber;
      
    } catch (e) {
      debugPrint('Gemini offline fallback: $e - Using enhanced rule-based GST: $gstBreakdown');
      // Offline result already populated
    }

    return result;
  }

  // ✅ NEW: Comprehensive GST Breakdown Extraction
  Map<String, double> _extractGstBreakdown(String text) {
    final lines = text.split('\n');
    final breakdown = {'cgst': 0.0, 'sgst': 0.0, 'igst': 0.0, 'subtotal': 0.0};

    // ✅ ROBUST PATTERNS FOR REAL BILLS
    final taxPatterns = {
      'cgst': ['CGST', 'C.G.S.T', 'Central GST'],
      'sgst': ['SGST', 'S.G.S.T', 'State GST'], 
      'igst': ['IGST', 'I.G.S.T', 'Integrated GST'],
    };

    for (final line in lines.reversed) {  // Bottom-up (taxes usually at bottom)
      final lower = line.toLowerCase();
      
      // ✅ PATTERN 1: "SGST @6% = ₹23.40" or "CGST 6% ₹12.00"
      for (final entry in taxPatterns.entries) {
        for (final keyword in entry.value) {
          if (lower.contains(keyword.toLowerCase())) {
            final taxAmount = _extractTaxAmount(line);
            if (taxAmount > 0) {
              breakdown[entry.key] = taxAmount;
              break;
            }
          }
        }
      }
      
      // ✅ PATTERN 2: Subtotal/Base Amount (before tax lines)
      if ((lower.contains('subtotal') || lower.contains('sub total') || lower.contains('base amt')) && 
          breakdown['subtotal'] == 0.0) {
        breakdown['subtotal'] = _extractTaxAmount(line);
      }
    }

    return breakdown;
  }

  // ✅ ENHANCED: Multiple real-world tax amount formats
  double _extractTaxAmount(String line) {
    // ₹23.40, 23.40, Rs.23.40, Rs 23/-
    final patterns = [
      r'₹?\\s*(\\d{1,3}(,\\d{3})*(\\.\\d{2})?|\\d{1,3}(,\\d{3})*/-)',
      r'@\\s*\\d+%?\\s*[-=]\\s*₹?\\s*\\d+',
      r'\\d+\\.\\d{2}',
      r'\\d{1,3}(,\\d{3})*',
    ];

    for (final pattern in patterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(line);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '') ?? 
                         match.group(0)!.replaceAll(RegExp(r'[^\\d.]'), '');
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0 && amount < 100000) {
          return amount;
        }
      }
    }
    return 0.0;
  }

  // SMART PROMPT (unchanged)
  String _prompt(String text) => '''
Parse Indian bill/receipt as JSON.

IMPORTANT:
- merchant: store name
- amount: FINAL TOTAL AMOUNT ONLY (biggest number with "total" keyword)
- date: transaction date (dd/MM/yyyy)
- category: BEST expense category from: Food, Grocery, Shopping, Education, Utility, Medical, Transport, General. Use merchant + items + gst.
- items: 2-5 line items [{"name": "item", "amount": number}]
- gstBreakdown: {"cgst": num, "sgst": num, "igst": num, "subtotal": num}

$text

Respond ONLY JSON:
'''; 

  // STRONG TOTAL DETECTION (unchanged)
  double _extractTotal(String text) {
    return OCRService.extractAmountDetails(text).amount;
  }

  // ADVANCED GSTIN (unchanged)
  String? _extractGstNumber(String text) {
    final gstMatch = RegExp(
      r'\\b[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\\b',
    ).firstMatch(text);
    return gstMatch?.group(0);
  }

  double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  // DUPE/RECURRING HASH (unchanged)
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


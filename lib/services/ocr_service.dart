import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class OCRService {
  static const _rupeeSymbol = '\u20B9';
  static const _currencyPattern = '(?:rs\\.?|inr|$_rupeeSymbol)?\\s*';
  static final RegExp _numberRegex = RegExp(
    '$_currencyPattern\\d[\\d,]*(?:\\.\\d{1,2})?',
    caseSensitive: false,
  );
  static final RegExp _keywordAmountRegex = RegExp(
    r'(total amount|grand total|amount payable|net amount|net payable|final amount|total due|amount due|payable amount|invoice total|total)\D{0,16}((?:rs\.?|inr|\u20B9)?\s*\d[\d,]*(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  static final RegExp _dateRegex = RegExp(
    r'\b(\d{1,4}[/-]\d{1,2}[/-]\d{1,4})\b',
  );

  static Future<String> extractText(File file) async {
    final result = await analyzeBill(file);
    return result.text.trim();
  }

  static Future<BillAnalysisResult> analyzeBill(File file) async {
    final preparedFile = await _prepareImageForOcr(file);
    final recognizedText = await _recognizeText(preparedFile);
    final text = recognizedText.text.trim();
    final amountResult = extractAmountDetails(
      text,
      recognizedText: recognizedText,
    );
    final merchant = extractMerchant(text);
    final date = extractDate(text);

    return BillAnalysisResult(
      text: text,
      amountResult: amountResult,
      date: date,
      merchant: merchant,
      category: detectCategory(merchant),
    );
  }

  static Future<Map<String, dynamic>> processBill(File file) async {
    final result = await analyzeBill(file);

    return {
      'text': result.text,
      'amount': result.amountResult.amount,
      'amountConfidence': result.amountResult.confidence,
      'amountAlternatives': result.amountResult.alternatives,
      'amountEvidence': result.amountResult.evidenceLine,
      'date': result.date,
      'merchant': result.merchant,
      'category': result.category,
    };
  }

  static Future<RecognizedText> _recognizeText(File file) async {
    final inputImage = InputImage.fromFile(file);
    final textRecognizer = TextRecognizer();

    try {
      return await textRecognizer.processImage(inputImage);
    } finally {
      await textRecognizer.close();
    }
  }

  static Future<File> _prepareImageForOcr(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return file;
      }

      var working = decoded;
      if (working.width < 1600) {
        working = img.copyResize(working, width: 1600);
      }

      working = _cropLikelyBillArea(working);
      working = img.grayscale(working);
      working = img.adjustColor(working, contrast: 1.35, brightness: 0.05);
      working = _applyThreshold(working);

      final tempDir = await getTemporaryDirectory();
      final preparedPath = path.join(
        tempDir.path,
        'ocr_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      final preparedFile = File(preparedPath);
      await preparedFile.writeAsBytes(img.encodePng(working), flush: true);
      return preparedFile;
    } catch (_) {
      return file;
    }
  }

  static img.Image _cropLikelyBillArea(img.Image source) {
    final marginX = math.max(8, (source.width * 0.03).round());
    final marginY = math.max(8, (source.height * 0.03).round());

    var left = source.width;
    var top = source.height;
    var right = 0;
    var bottom = 0;

    for (final pixel in source) {
      final luminance = img.getLuminanceRgb(pixel.r, pixel.g, pixel.b);
      if (luminance < 240) {
        if (pixel.x < left) left = pixel.x;
        if (pixel.y < top) top = pixel.y;
        if (pixel.x > right) right = pixel.x;
        if (pixel.y > bottom) bottom = pixel.y;
      }
    }

    if (right <= left || bottom <= top) {
      return source;
    }

    final cropX = math.max(0, left - marginX);
    final cropY = math.max(0, top - marginY);
    final cropWidth =
        math.min(source.width - cropX, (right - left) + (marginX * 2));
    final cropHeight =
        math.min(source.height - cropY, (bottom - top) + (marginY * 2));

    if (cropWidth < source.width * 0.35 ||
        cropHeight < source.height * 0.35) {
      return source;
    }

    return img.copyCrop(
      source,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );
  }

  static img.Image _applyThreshold(img.Image source) {
    final threshold = _adaptiveThreshold(source);
    final output = img.Image.from(source);

    for (final pixel in output) {
      final luminance = img.getLuminanceRgb(pixel.r, pixel.g, pixel.b);
      final value = luminance >= threshold ? 255 : 0;
      pixel
        ..r = value
        ..g = value
        ..b = value;
    }

    return output;
  }

  static int _adaptiveThreshold(img.Image source) {
    num total = 0;
    var count = 0;

    for (final pixel in source) {
      total += img.getLuminanceRgb(pixel.r, pixel.g, pixel.b);
      count++;
    }

    if (count == 0) {
      return 160;
    }

    return (total / count).round().clamp(135, 205);
  }

  static AmountExtractionResult extractAmountDetails(
    String text, {
    RecognizedText? recognizedText,
  }) {
    final entries = _buildLineEntries(text, recognizedText);
    final keywordBoost = _extractKeywordHints(text);
    final candidates = <_AmountCandidate>[];

    for (final entry in entries) {
      if (_shouldSkipLine(entry.text)) {
        continue;
      }

      for (final match in _numberRegex.allMatches(entry.text)) {
        final rawMatch = match.group(0)?.trim();
        if (rawMatch == null || rawMatch.isEmpty) {
          continue;
        }

        final value = _parseAmount(rawMatch);
        if (value == null || value < 10) {
          continue;
        }

        if (_looksLikeDate(entry.text, rawMatch) ||
            _looksLikeReference(entry.text)) {
          continue;
        }

        final score = _scoreCandidate(
          entry: entry,
          rawValue: rawMatch,
          value: value,
          keywordBoost: keywordBoost[value.round()],
        );

        if (score <= 0) {
          continue;
        }

        candidates.add(
          _AmountCandidate(
            value: value,
            score: score,
            lineText: entry.text,
            reasons: _buildReasons(
              entry.text,
              rawMatch,
              value,
              entry.positionRatio,
            ),
          ),
        );
      }
    }

    if (candidates.isEmpty) {
      return const AmountExtractionResult(
        amount: 0,
        confidence: 0,
        label: 'Low Confidence',
        alternatives: [],
      );
    }

    candidates.sort((a, b) {
      final scoreComparison = b.score.compareTo(a.score);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      return b.value.compareTo(a.value);
    });

    final best = candidates.first;
    final secondBest = candidates.length > 1 ? candidates[1] : null;
    final topDistinct = <double>[];

    for (final candidate in candidates) {
      final alreadyPresent = topDistinct.any(
        (value) => (value - candidate.value).abs() < 0.01,
      );
      if (!alreadyPresent) {
        topDistinct.add(candidate.value);
      }
      if (topDistinct.length == 3) {
        break;
      }
    }

    final confidence = _calculateConfidence(best, secondBest);

    return AmountExtractionResult(
      amount: best.value,
      confidence: confidence,
      label: _confidenceLabel(confidence),
      alternatives: topDistinct,
      evidenceLine: best.lineText,
      reasons: best.reasons,
    );
  }

  static double extractAmount(String text) {
    return extractAmountDetails(text).amount;
  }

  static List<_LineEntry> _buildLineEntries(
    String text,
    RecognizedText? recognizedText,
  ) {
    if (recognizedText != null) {
      final entries = <_LineEntry>[];
      final lines = recognizedText.blocks
          .expand((block) => block.lines)
          .where((line) => line.text.trim().isNotEmpty)
          .toList();

      final imageHeight = lines.fold<double>(
        0,
        (maxBottom, line) => math.max(
          maxBottom,
          line.boundingBox.bottom.toDouble(),
        ),
      );

      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        final ratio = imageHeight <= 0
            ? (index + 1) / math.max(lines.length, 1)
            : line.boundingBox.center.dy / imageHeight;
        entries.add(
          _LineEntry(
            text: line.text.trim(),
            positionRatio: ratio.clamp(0.0, 1.0),
          ),
        );
      }

      if (entries.isNotEmpty) {
        return entries;
      }
    }

    final rawLines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return List.generate(
      rawLines.length,
      (index) => _LineEntry(
        text: rawLines[index],
        positionRatio: rawLines.isEmpty ? 0 : (index + 1) / rawLines.length,
      ),
    );
  }

  static Map<int, int> _extractKeywordHints(String text) {
    final hints = <int, int>{};

    for (final match in _keywordAmountRegex.allMatches(text)) {
      final rawValue = match.group(2);
      if (rawValue == null) {
        continue;
      }

      final value = _parseAmount(rawValue);
      if (value == null) {
        continue;
      }

      hints[value.round()] = (hints[value.round()] ?? 0) + 70;
    }

    return hints;
  }

  static int _scoreCandidate({
    required _LineEntry entry,
    required String rawValue,
    required double value,
    int? keywordBoost,
  }) {
    final line = entry.text.toLowerCase();
    var score = 0;

    if (value < 10) {
      return -100;
    }
    if (value >= 50) {
      score += 20;
    }
    if (value >= 1000) {
      score += 18;
    }
    if (value >= 10000) {
      score += 16;
    }

    if (line.contains('grand total')) score += 65;
    if (line.contains('total amount')) score += 60;
    if (line.contains('amount payable')) score += 58;
    if (line.contains('net payable')) score += 55;
    if (line.contains('net amount')) score += 50;
    if (line.contains('final amount')) score += 50;
    if (line.contains('total')) score += 40;
    if (line.contains('grand')) score += 24;
    if (line.contains('amount')) score += 18;
    if (line.contains('payable')) score += 18;
    if (line.contains('due')) score += 14;
    if (line.contains('balance')) score += 10;

    if (line.contains('subtotal')) score -= 28;
    if (line.contains('tax')) score -= 40;
    if (line.contains('cgst')) score -= 45;
    if (line.contains('sgst')) score -= 45;
    if (line.contains('igst')) score -= 45;
    if (line.contains('discount')) score -= 26;
    if (line.contains('round off')) score -= 20;
    if (line.contains('qty') || line.contains('quantity')) score -= 14;
    if (line.contains('rate') || line.contains('price')) score -= 12;

    if (rawValue.contains(_rupeeSymbol) ||
        line.contains(_rupeeSymbol) ||
        line.contains('rs.') ||
        line.contains('rs ') ||
        line.contains('inr')) {
      score += 20;
    }

    if (entry.positionRatio >= 0.70) {
      score += 20;
    } else if (entry.positionRatio >= 0.55) {
      score += 12;
    }

    score += math.min((value / 1500).floor(), 25);
    score += keywordBoost ?? 0;

    if (entry.text.length <= 40) {
      score += 4;
    }

    return score;
  }

  static bool _shouldSkipLine(String line) {
    final lower = line.toLowerCase();

    if (lower.contains('%')) {
      return true;
    }
    if (lower.contains('phone') || lower.contains('mobile')) {
      return true;
    }

    return false;
  }

  static bool _looksLikeDate(String line, String rawValue) {
    if (_dateRegex.hasMatch(line)) {
      final compactRaw = rawValue.replaceAll(RegExp(r'[^\d]'), '');
      final compactLine = line.replaceAll(RegExp(r'[^\d/]'), '');
      if (compactRaw.length >= 6 && compactLine.contains(compactRaw)) {
        return true;
      }
    }

    return false;
  }

  static bool _looksLikeReference(String line) {
    final lower = line.toLowerCase();
    const markers = [
      'invoice no',
      'invoice #',
      'bill no',
      'receipt no',
      'receipt #',
      'ref',
      'reference',
      'txn',
      'transaction',
      'order id',
      'gstin',
      'hsn',
      'table no',
      'token',
      'student id',
      'roll no',
    ];

    final hasMarker = markers.any(lower.contains);
    final hasTotalWord = lower.contains('total') ||
        lower.contains('amount') ||
        lower.contains('payable');

    return hasMarker && !hasTotalWord;
  }

  static double? _parseAmount(String raw) {
    final cleaned = raw
        .replaceAll(
          RegExp('rs\\.?|inr|$_rupeeSymbol', caseSensitive: false),
          '',
        )
        .replaceAll(',', '')
        .trim();

    return double.tryParse(cleaned);
  }

  static double _calculateConfidence(
    _AmountCandidate best,
    _AmountCandidate? secondBest,
  ) {
    final base = (best.score / 140).clamp(0.0, 1.0);
    final gapBoost = secondBest == null
        ? 0.12
        : ((best.score - secondBest.score) / 120).clamp(0.0, 0.18);

    return (base + gapBoost).clamp(0.0, 0.99);
  }

  static String _confidenceLabel(double confidence) {
    if (confidence >= 0.8) return 'High Confidence';
    if (confidence >= 0.55) return 'Medium Confidence';
    return 'Low Confidence';
  }

  static List<String> _buildReasons(
    String line,
    String rawValue,
    double value,
    double positionRatio,
  ) {
    final reasons = <String>[];
    final lower = line.toLowerCase();

    if (lower.contains('total')) reasons.add('Matched total keyword');
    if (lower.contains('amount') || lower.contains('payable')) {
      reasons.add('Matched amount/payable keyword');
    }
    if (positionRatio >= 0.70) {
      reasons.add('Found near the bottom of the bill');
    }
    if (rawValue.contains(_rupeeSymbol) ||
        lower.contains(_rupeeSymbol) ||
        lower.contains('rs.') ||
        lower.contains('inr')) {
      reasons.add('Included a currency marker');
    }
    if (value >= 1000) {
      reasons.add('Value is large enough to be a likely final amount');
    }

    return reasons;
  }

  static DateTime extractDate(String text) {
    final regex = RegExp(
      r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2})\b',
    );
    final match = regex.firstMatch(text);

    if (match != null) {
      final raw = match.group(0)!;
      final direct = DateTime.tryParse(raw);
      if (direct != null) {
        return direct;
      }

      const formats = [
        'dd/MM/yyyy',
        'dd-MM-yyyy',
        'dd/MM/yy',
        'dd-MM-yy',
        'MM/dd/yyyy',
        'MM-dd-yyyy',
        'yyyy-MM-dd',
        'yyyy/MM/dd',
      ];

      for (final format in formats) {
        try {
          return DateFormat(format).parseStrict(raw);
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

    const blockedWords = [
      'tax invoice',
      'invoice',
      'bill',
      'receipt',
      'gst',
      'phone',
      'mobile',
      'date',
    ];

    for (final line in lines.take(5)) {
      final lower = line.toLowerCase();
      if (lower.length < 3) {
        continue;
      }
      if (blockedWords.any(lower.contains)) {
        continue;
      }
      if (RegExp(r'\d{4,}').hasMatch(line)) {
        continue;
      }
      return line;
    }

    return lines.isNotEmpty ? lines.first : 'Unknown';
  }

  static String detectCategory(String merchant) {
    final normalized = merchant.toLowerCase();

    if (normalized.contains('restaurant') ||
        normalized.contains('hotel') ||
        normalized.contains('cafe')) {
      return 'Food';
    }
    if (normalized.contains('uber') ||
        normalized.contains('ola') ||
        normalized.contains('taxi')) {
      return 'Travel';
    }
    if (normalized.contains('mart') ||
        normalized.contains('store') ||
        normalized.contains('supermarket')) {
      return 'Grocery';
    }
    if (normalized.contains('college') ||
        normalized.contains('school') ||
        normalized.contains('university')) {
      return 'Education';
    }
    if (normalized.contains('pharma') ||
        normalized.contains('clinic') ||
        normalized.contains('hospital')) {
      return 'Medical';
    }

    return 'General';
  }
}

class BillAnalysisResult {
  final String text;
  final AmountExtractionResult amountResult;
  final DateTime date;
  final String merchant;
  final String category;

  const BillAnalysisResult({
    required this.text,
    required this.amountResult,
    required this.date,
    required this.merchant,
    required this.category,
  });
}

class AmountExtractionResult {
  final double amount;
  final double confidence;
  final String label;
  final List<double> alternatives;
  final String? evidenceLine;
  final List<String> reasons;

  const AmountExtractionResult({
    required this.amount,
    required this.confidence,
    required this.label,
    required this.alternatives,
    this.evidenceLine,
    this.reasons = const [],
  });
}

class _LineEntry {
  final String text;
  final double positionRatio;

  const _LineEntry({
    required this.text,
    required this.positionRatio,
  });
}

class _AmountCandidate {
  final double value;
  final int score;
  final String lineText;
  final List<String> reasons;

  const _AmountCandidate({
    required this.value,
    required this.score,
    required this.lineText,
    required this.reasons,
  });
}

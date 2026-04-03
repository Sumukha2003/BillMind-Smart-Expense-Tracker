import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class OCRService {
  static final DateTime _minValidBillDate = DateTime(2020, 1, 1);
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
  static final RegExp _strongTotalKeywordRegex = RegExp(
    r'\b(total amount after tax|invoice amount|grand total|total amount|invoice total|final amount|amount payable|net payable|net amount|amount due|total due|payable amount|total|amount)\b',
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
    File? preparedFile;

    try {
      preparedFile = await _prepareImageForOcr(file);
      final recognizedText = await _recognizeBestText(
        originalFile: file,
        preparedFile: preparedFile,
      );
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
        category: detectCategory(merchant, text: text),
      );
    } finally {
      if (preparedFile != null && preparedFile.path != file.path) {
        try {
          await preparedFile.delete();
        } catch (_) {}
      }
    }
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

  static Future<RecognizedText> _recognizeBestText({
    required File originalFile,
    required File preparedFile,
  }) async {
    final originalResult = await _recognizeText(originalFile);
    if (preparedFile.path == originalFile.path) {
      return originalResult;
    }

    final preparedResult = await _recognizeText(preparedFile);
    final originalScore = _recognizedTextQualityScore(originalResult);
    final preparedScore = _recognizedTextQualityScore(preparedResult);

    return preparedScore > originalScore ? preparedResult : originalResult;
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

  static int _recognizedTextQualityScore(RecognizedText recognizedText) {
    final text = recognizedText.text.trim();
    if (text.isEmpty) {
      return 0;
    }

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final amount = extractAmountDetails(text, recognizedText: recognizedText);
    final merchant = extractMerchant(text);
    final date = extractDate(text);

    var score = math.min(text.length, 240);
    score += math.min(lines.length * 12, 120);

    if (amount.amount > 0) {
      score += 120 + (amount.confidence * 60).round();
    }
    if (merchant != 'Unknown') {
      score += 50;
    }
    if (date != null) {
      score += 40;
    }

    return score;
  }

  static AmountExtractionResult extractAmountDetails(
    String text, {
    RecognizedText? recognizedText,
  }) {
    final entries = _buildLineEntries(text, recognizedText);
    final keywordBoost = _extractKeywordHints(text);
    final candidates = <_AmountCandidate>[];
    final strongKeywordCandidates = <_AmountCandidate>[];

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
        if (_looksLikeIdentifierNumber(entry.text, rawMatch, value)) {
          continue;
        }

        if (_looksLikeDate(entry.text, rawMatch) ||
            _looksLikeYearOrDateFragment(entry.text, rawMatch, value) ||
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

        final candidate = _AmountCandidate(
          value: value,
          score: score,
          lineText: entry.text,
          reasons: _buildReasons(
            entry.text,
            rawMatch,
            value,
            entry.positionRatio,
          ),
        );
        candidates.add(candidate);

        if (_hasStrongTotalKeyword(entry.text)) {
          strongKeywordCandidates.add(candidate);
        }
      }
    }

    final activeCandidates =
        strongKeywordCandidates.isNotEmpty ? strongKeywordCandidates : candidates;

    if (activeCandidates.isEmpty) {
      return const AmountExtractionResult(
        amount: 0,
        confidence: 0,
        label: 'Low Confidence',
        alternatives: [],
      );
    }

    activeCandidates.sort((a, b) {
      final scoreComparison = b.score.compareTo(a.score);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      return b.value.compareTo(a.value);
    });

    final best = activeCandidates.first;
    final secondBest = activeCandidates.length > 1 ? activeCandidates[1] : null;
    final topDistinct = <double>[];

    for (final candidate in activeCandidates) {
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

    final keywordMatches = _strongTotalKeywordRegex.allMatches(line).length;
    score += keywordMatches * 18;

    if (line.contains('total amount after tax')) score += 110;
    if (line.contains('invoice amount')) score += 95;
    if (line.contains('grand total')) score += 65;
    if (line.contains('total amount')) score += 60;
    if (line.contains('amount payable')) score += 58;
    if (line.contains('net payable')) score += 55;
    if (line.contains('net amount')) score += 50;
    if (line.contains('final amount')) score += 50;
    if (line.contains('bill amount')) score += 44;
    if (line.contains('amount due')) score += 42;
    if (line.contains('total')) score += 40;
    if (line.contains('grand')) score += 24;
    if (line.contains('amount')) score += 18;
    if (line.contains('payable')) score += 18;
    if (line.contains('due')) score += 14;
    if (line.contains('balance')) score += 10;

    if (line.contains('subtotal')) score -= 28;
    if (line.contains('sub total')) score -= 28;
    if (line.contains('taxable')) score -= 75;
    if (line.contains('taxable amount')) score -= 90;
    if (line.contains('taxable amt')) score -= 90;
    if (line.contains('base amount')) score -= 55;
    if (line.contains('basic amount')) score -= 55;
    if (line.contains('gross amount')) score -= 35;
    if (line.contains('gross total')) score -= 22;
    if (line.contains('before tax')) score -= 60;
    if (line.contains('before gst')) score -= 60;
    if (line.contains('pre-tax')) score -= 60;
    if (line.contains('pre tax')) score -= 60;
    if (line.contains('assessable')) score -= 65;
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

    if (_isLikelyDateLine(line)) {
      score -= 90;
    }
    if (_isYearLikeValue(value, rawValue)) {
      score -= 120;
    }
    if (_looksLikeIdentifierNumber(entry.text, rawValue, value)) {
      score -= 200;
    }

    score += math.min((value / 1500).floor(), 25);
    score += keywordBoost ?? 0;

    if (entry.text.length <= 40) {
      score += 4;
    }
    if (_strongTotalKeywordRegex.hasMatch(line)) {
      score += 12;
    }

    return score;
  }

  static bool _hasStrongTotalKeyword(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('taxable amount') ||
        lower.contains('taxable amt') ||
        lower.contains('taxable')) {
      return false;
    }

    return lower.contains('total amount after tax') ||
        lower.contains('invoice amount') ||
        lower.contains('grand total') ||
        lower.contains('total amount') ||
        lower.contains('invoice total') ||
        lower.contains('final amount') ||
        lower.contains('amount payable') ||
        lower.contains('net payable') ||
        lower.contains('net amount') ||
        lower.contains('amount due') ||
        lower.contains('total due') ||
        lower.contains('payable amount') ||
        lower.contains('total') ||
        lower.contains('amount');
  }

  static bool _shouldSkipLine(String line) {
    final lower = line.toLowerCase();

    if (lower.contains('%')) {
      return true;
    }
    if (lower.contains('phone') || lower.contains('mobile')) {
      return true;
    }
    if (lower.contains('gstin') || lower.contains('hsn')) {
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

  static bool _looksLikeYearOrDateFragment(
    String line,
    String rawValue,
    double value,
  ) {
    final lower = line.toLowerCase();
    final digits = rawValue.replaceAll(RegExp(r'[^\d]'), '');

    if (_isYearLikeValue(value, rawValue) && _isLikelyDateLine(lower)) {
      return true;
    }

    if ((lower.contains('/') || lower.contains('-')) &&
        digits.length <= 4 &&
        _isLikelyDateLine(lower)) {
      return true;
    }

    if (digits.length == 6 || digits.length == 8) {
      final parsed = _parseCompactDateDigits(digits);
      if (parsed != null && _isLikelyDateLine(lower)) {
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
      'account',
      'account no',
      'account number',
      'a/c',
      'a/c no',
      'acc no',
      'bank account',
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

  static bool _looksLikeIdentifierNumber(
    String line,
    String rawValue,
    double value,
  ) {
    final lower = line.toLowerCase();
    final digits = rawValue.replaceAll(RegExp(r'[^\d]'), '');
    final hasDecimal = rawValue.contains('.');
    final hasCurrency = rawValue.contains(_rupeeSymbol) ||
        lower.contains(_rupeeSymbol) ||
        lower.contains('rs.') ||
        lower.contains('rs ') ||
        lower.contains('inr');
    final hasReferenceLabel = RegExp(
      r'\b(account|account no|account number|a/c|acc no|ref|reference|txn|transaction|id|no\.?|number)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    final hasIdentifierSeparators =
        line.contains('_') || line.contains(':') || line.contains('#');
    final lineDigits = line.replaceAll(RegExp(r'[^\d]'), '');
    final hasMixedAlphaNumeric = RegExp(
      r'(?=.*[a-zA-Z])(?=.*\d)',
    ).hasMatch(line);
    final hasManyDigitGroups =
        RegExp(r'\d').allMatches(line).length >= 10 && !hasCurrency;

    if (digits.length >= 9 && !hasDecimal && !hasCurrency) {
      return true;
    }

    if (hasReferenceLabel && digits.length >= 6 && !hasDecimal) {
      return true;
    }

    if (hasIdentifierSeparators && digits.length >= 6 && !hasDecimal) {
      return true;
    }

    if (hasMixedAlphaNumeric && lineDigits.length >= 8 && !hasCurrency) {
      return true;
    }

    if (hasManyDigitGroups && !_hasStrongTotalKeyword(line)) {
      return true;
    }

    if (value >= 10000000 && !hasCurrency && !lower.contains('total')) {
      return true;
    }

    return false;
  }

  static bool _isLikelyDateLine(String lowerLine) {
    const dateWords = [
      'date',
      'dated',
      'invoice date',
      'bill date',
      'receipt date',
      'txn date',
      'transaction date',
      'time',
      'year',
      'fy',
      'period',
    ];

    final hasDateWord = dateWords.any(lowerLine.contains);
    final hasDateSeparator = lowerLine.contains('/') || lowerLine.contains('-');
    final hasMonthName = RegExp(
      r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)\b',
      caseSensitive: false,
    ).hasMatch(lowerLine);

    return hasDateWord || hasDateSeparator || hasMonthName;
  }

  static bool _isYearLikeValue(double value, String rawValue) {
    final digits = rawValue.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length != 4) {
      return false;
    }

    final numeric = int.tryParse(digits);
    if (numeric == null) {
      return false;
    }

    return numeric >= 2000 && numeric <= 2099 && value == numeric.toDouble();
  }

  static DateTime? _parseCompactDateDigits(String digits) {
    final currentYear = DateTime.now().year;

    if (digits.length == 8) {
      final yyyy = int.tryParse(digits.substring(0, 4));
      final mm = int.tryParse(digits.substring(4, 6));
      final dd = int.tryParse(digits.substring(6, 8));
      if (_looksLikeValidDateParts(yyyy, mm, dd, currentYear)) {
        return DateTime(yyyy!, mm!, dd!);
      }

      final dd2 = int.tryParse(digits.substring(0, 2));
      final mm2 = int.tryParse(digits.substring(2, 4));
      final yyyy2 = int.tryParse(digits.substring(4, 8));
      if (_looksLikeValidDateParts(yyyy2, mm2, dd2, currentYear)) {
        return DateTime(yyyy2!, mm2!, dd2!);
      }
    }

    if (digits.length == 6) {
      final dd = int.tryParse(digits.substring(0, 2));
      final mm = int.tryParse(digits.substring(2, 4));
      final yy = int.tryParse(digits.substring(4, 6));
      final yyyy = yy == null ? null : 2000 + yy;
      if (_looksLikeValidDateParts(yyyy, mm, dd, currentYear)) {
        return DateTime(yyyy!, mm!, dd!);
      }
    }

    return null;
  }

  static bool _looksLikeValidDateParts(
    int? year,
    int? month,
    int? day,
    int currentYear,
  ) {
    if (year == null || month == null || day == null) {
      return false;
    }

    if (year < 2000 || year > currentYear + 1) {
      return false;
    }
    if (month < 1 || month > 12) {
      return false;
    }
    if (day < 1 || day > 31) {
      return false;
    }

    return true;
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

    if (lower.contains('total amount after tax')) {
      reasons.add('Matched total amount after tax keyword');
    } else if (lower.contains('invoice amount')) {
      reasons.add('Matched invoice amount keyword');
    } else if (lower.contains('grand total')) {
      reasons.add('Matched grand total keyword');
    } else if (lower.contains('total amount')) {
      reasons.add('Matched total amount keyword');
    } else if (lower.contains('amount payable')) {
      reasons.add('Matched amount payable keyword');
    } else if (lower.contains('final amount')) {
      reasons.add('Matched final amount keyword');
    } else if (lower.contains('net amount') || lower.contains('net payable')) {
      reasons.add('Matched net total keyword');
    } else if (lower.contains('total')) {
      reasons.add('Matched total keyword');
    } else if (lower.contains('amount')) {
      reasons.add('Matched amount keyword');
    }
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

  static DateTime? extractDate(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    DateTime? bestDate;
    var bestScore = -1;

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final lineScoreBase = math.max(0, 50 - (index * 4));

      for (final candidate in _extractDateCandidatesFromLine(line)) {
        final parsed = _parseBillDate(candidate);
        if (parsed == null) {
          continue;
        }

        var score = lineScoreBase;
        final lower = line.toLowerCase();
        if (lower.contains('date')) score += 40;
        if (lower.contains('invoice')) score -= 8;
        if (lower.contains('due')) score -= 12;

        if (score > bestScore) {
          bestDate = parsed;
          bestScore = score;
        }
      }
    }

    return bestDate;
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
      'payment completed',
      'completed successfully',
      'transaction information',
      'uploaded successfully',
      'gst',
      'phone',
      'mobile',
      'date',
    ];

    final candidates = <String, int>{};

    for (var index = 0; index < math.min(lines.length, 8); index++) {
      final line = lines[index];
      final lower = line.toLowerCase();
      final normalized = line.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (normalized.length < 3 || normalized.length > 48) {
        continue;
      }
      if (blockedWords.any(lower.contains)) {
        continue;
      }
      if (RegExp(r'\d{4,}').hasMatch(normalized)) {
        continue;
      }
      if (RegExp(r'^[\W_]+$').hasMatch(normalized)) {
        continue;
      }
      if (RegExp(r'^(cash|card|upi|qty|rate)\b', caseSensitive: false)
          .hasMatch(normalized)) {
        continue;
      }

      var score = 100 - (index * 10);
      if (!RegExp(r'\d').hasMatch(normalized)) {
        score += 25;
      }
      if (RegExp(
        r'\b(restaurant|resto|cafe|store|mart|supermarket|medical|pharmacy|hotel|traders|enterprises|bakers|foods?)\b',
        caseSensitive: false,
      ).hasMatch(normalized)) {
        score += 30;
      }
      if (normalized == normalized.toUpperCase()) {
        score += 10;
      }
      if (normalized.split(' ').length <= 5) {
        score += 8;
      }

      candidates[normalized] = score;
    }

    if (candidates.isEmpty) {
      return 'Unknown';
    }

    final sorted = candidates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  static String detectCategory(String merchant, {String text = ''}) {
    final normalized = '$merchant\n$text'.toLowerCase();

    if (normalized.contains('restaurant') ||
        normalized.contains('hotel') ||
        normalized.contains('cafe') ||
        normalized.contains('swiggy') ||
        normalized.contains('zomato')) {
      return 'Food';
    }
    if (normalized.contains('uber') ||
        normalized.contains('ola') ||
        normalized.contains('taxi') ||
        normalized.contains('auto') ||
        normalized.contains('metro')) {
      return 'Transport';
    }
    if (normalized.contains('mart') ||
        normalized.contains('store') ||
        normalized.contains('supermarket') ||
        normalized.contains('grocery') ||
        normalized.contains('hypermarket')) {
      return 'Grocery';
    }
    if (normalized.contains('college') ||
        normalized.contains('school') ||
        normalized.contains('university') ||
        normalized.contains('tuition') ||
        normalized.contains('fee')) {
      return 'Education';
    }
    if (normalized.contains('pharma') ||
        normalized.contains('clinic') ||
        normalized.contains('hospital') ||
        normalized.contains('medical') ||
        normalized.contains('medicine')) {
      return 'Medical';
    }
    if (normalized.contains('amazon') ||
        normalized.contains('flipkart') ||
        normalized.contains('myntra')) {
      return 'Shopping';
    }
    if (normalized.contains('electricity') ||
        normalized.contains('water bill') ||
        normalized.contains('gas bill')) {
      return 'Utility';
    }

    return 'General';
  }

  static Iterable<String> _extractDateCandidatesFromLine(String line) sync* {
    final numeric = RegExp(
      r'\b\d{1,4}[/-]\d{1,2}[/-]\d{1,4}\b',
      caseSensitive: false,
    );
    for (final match in numeric.allMatches(line)) {
      final value = match.group(0);
      if (value != null) {
        yield value;
      }
    }

    final withMonth = RegExp(
      r'\b\d{1,2}(?:st|nd|rd|th)?[\s,-]+(?:jan|january|feb|february|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december)[a-z]*[\s,-]+\d{2,4}\b',
      caseSensitive: false,
    );
    for (final match in withMonth.allMatches(line)) {
      final value = match.group(0);
      if (value != null) {
        yield value;
      }
    }

    final monthFirst = RegExp(
      r'\b(?:jan|january|feb|february|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december)[a-z]*[\s,-]+\d{1,2}(?:st|nd|rd|th)?(?:,)?[\s,-]+\d{2,4}\b',
      caseSensitive: false,
    );
    for (final match in monthFirst.allMatches(line)) {
      final value = match.group(0);
      if (value != null) {
        yield value;
      }
    }
  }

  static DateTime? _parseBillDate(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'(\d)(st|nd|rd|th)\b', caseSensitive: false), r'$1')
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final direct = DateTime.tryParse(cleaned);
    if (_isValidBillDate(direct)) {
      return DateTime(direct!.year, direct.month, direct.day);
    }

    const formats = [
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'dd/MM/yy',
      'dd-MM-yy',
      'MM/dd/yyyy',
      'MM-dd-yyyy',
      'MM/dd/yy',
      'MM-dd-yy',
      'yyyy-MM-dd',
      'yyyy/MM/dd',
      'dd MMM yyyy',
      'dd MMM yy',
      'dd MMMM yyyy',
      'dd MMMM yy',
      'MMM dd yyyy',
      'MMMM dd yyyy',
      'MMM dd yy',
      'MMMM dd yy',
    ];

    for (final format in formats) {
      try {
        final parsed = DateFormat(format).parseStrict(cleaned);
        if (_isValidBillDate(parsed)) {
          return DateTime(parsed.year, parsed.month, parsed.day);
        }
      } catch (_) {}
    }

    return null;
  }

  static bool _isValidBillDate(DateTime? value) {
    if (value == null) {
      return false;
    }

    final normalized = DateTime(value.year, value.month, value.day);
    final today = DateTime.now();
    final latestAllowed = DateTime(today.year, today.month, today.day)
        .add(const Duration(days: 1));

    return !normalized.isBefore(_minValidBillDate) &&
        !normalized.isAfter(latestAllowed);
  }
}

class BillAnalysisResult {
  final String text;
  final AmountExtractionResult amountResult;
  final DateTime? date;
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

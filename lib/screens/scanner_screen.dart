import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/expense.dart';
import '../services/duplicate_service.dart';
import '../services/gemini_service.dart';
import '../services/ocr_service.dart';
import '../services/pdf_service.dart';
import 'result_screen.dart';

class ScannerScreen extends ConsumerWidget {
  const ScannerScreen({super.key});

  static final ImagePicker _picker = ImagePicker();

  Future<void> scanAndProcess(BuildContext context, WidgetRef ref) async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    if (!context.mounted) return;

    await _processFile(context, ref, File(picked.path));
  }

  Future<void> pickImageFromGallery(BuildContext context, WidgetRef ref) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (!context.mounted) return;

    await _processFile(context, ref, File(picked.path));
  }

  Future<void> pickPDF(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.single.path == null) return;

    final image = await PDFService.convertFirstPageToImage(
      result.files.single.path!,
    );
    if (!context.mounted) return;

    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to process PDF')),
      );
      return;
    }

    await _processFile(context, ref, image);
  }

  Future<void> _processFile(
    BuildContext context,
    WidgetRef ref,
    File file,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ocrResult = await OCRService.analyzeBill(file);
    final aiResult = await GeminiService().parseBill(ocrResult.text);

    final merchant = _pickMerchant(
      aiMerchant: aiResult['merchant'],
      ocrMerchant: ocrResult.merchant,
    );
    final amount = _pickAmount(
      ocrResult: ocrResult.amountResult,
      aiAmount: aiResult['amount'],
    );
    final date = _dateOrFallback(aiResult['date'], ocrResult.date);
    final category = _stringOrFallback(aiResult['category'], ocrResult.category);

    final previewExpense = Expense(
      id: 'preview',
      merchant: merchant,
      amount: amount,
      category: category,
      date: date,
      imagePath: file.path,
    );

    if (DuplicateService.isDuplicate(previewExpense) && context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Possible duplicate bill detected')),
      );
    }

    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          imagePath: file.path,
          merchant: merchant,
          amount: amount,
          date: date,
          category: category,
          amountConfidence: ocrResult.amountResult.confidence,
          amountConfidenceLabel: ocrResult.amountResult.label,
          amountAlternatives: ocrResult.amountResult.alternatives,
          amountEvidence: ocrResult.amountResult.evidenceLine,
          amountReasons: ocrResult.amountResult.reasons,
        ),
      ),
    );
  }

  String _pickMerchant({
    required dynamic aiMerchant,
    required String ocrMerchant,
  }) {
    final aiValue = _stringOrNull(aiMerchant);
    if (aiValue == null) {
      return ocrMerchant;
    }

    if (ocrMerchant == 'Unknown') {
      return aiValue;
    }

    return aiValue.length >= ocrMerchant.length ? aiValue : ocrMerchant;
  }

  double _pickAmount({
    required AmountExtractionResult ocrResult,
    required dynamic aiAmount,
  }) {
    final aiValue = _doubleOrNull(aiAmount);
    if (ocrResult.amount > 0 && ocrResult.confidence >= 0.55) {
      return ocrResult.amount;
    }

    if (aiValue == null || aiValue <= 0) {
      return ocrResult.amount;
    }

    final aiMatchesOcrAlternative = ocrResult.alternatives.any(
      (candidate) => (candidate - aiValue).abs() < 1,
    );

    if (ocrResult.amount <= 0 || aiMatchesOcrAlternative) {
      return aiValue;
    }

    return ocrResult.amount > 0 ? ocrResult.amount : aiValue;
  }

  String _stringOrFallback(dynamic value, String fallback) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? fallback : text;
  }

  String? _stringOrNull(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  double? _doubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  DateTime _dateOrFallback(dynamic value, DateTime fallback) {
    if (value is DateTime) return value;
    if (value is String) return OCRService.extractDate(value);
    return fallback;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF151A18) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2A3430)
        : const Color(0xFFE4ECE8);
    final secondaryTextColor = isDark
        ? const Color(0xFFB6C2BD)
        : const Color(0xFF5E6A66);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Bill')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF0A0A0A),
                    Color(0xFF111715),
                  ]
                : const [
                    Color(0xFFF4FBF8),
                    Color(0xFFFFFFFF),
                  ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1D9E75),
                    Color(0xFF146B59),
                  ],
                ),
                boxShadow: isDark
                    ? const []
                    : const [
                        BoxShadow(
                          color: Color(0x1F1D9E75),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.document_scanner_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Capture receipts your way',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan from the camera, import a photo, or convert the '
                    'first page of a PDF into a reviewable bill.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ActionCard(
              title: 'Scan with Camera',
              subtitle:
                  'Best for a fresh bill capture with the fastest OCR flow.',
              icon: Icons.camera_alt_rounded,
              accent: const Color(0xFF1D9E75),
              isDark: isDark,
              onTap: () => scanAndProcess(context, ref),
            ),
            const SizedBox(height: 14),
            _ActionCard(
              title: 'Upload Image',
              subtitle: 'Choose an existing receipt photo from your gallery.',
              icon: Icons.photo_library_rounded,
              accent: const Color(0xFF2F80ED),
              isDark: isDark,
              onTap: () => pickImageFromGallery(context, ref),
            ),
            const SizedBox(height: 14),
            _ActionCard(
              title: 'Upload PDF',
              subtitle:
                  'Import a PDF and extract the first page for OCR and AI parsing.',
              icon: Icons.picture_as_pdf_rounded,
              accent: const Color(0xFFD85A30),
              isDark: isDark,
              onTap: () => pickPDF(context, ref),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What happens next',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'OCR extracts the text and totals.',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gemini improves merchant, date, and category guesses.',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You review the result before saving and auto-uploading.',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? const Color(0xFF151A18) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2A3430)
        : const Color(0xFFE6ECE8);
    final secondaryTextColor = isDark
        ? const Color(0xFFB6C2BD)
        : const Color(0xFF5E6A66);
    final arrowColor = isDark
        ? const Color(0xFF8B9A95)
        : const Color(0xFF97A6A1);

    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
            boxShadow: isDark
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x0A101828),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: secondaryTextColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_rounded,
                color: arrowColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

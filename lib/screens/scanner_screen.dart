import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ocr_service.dart';
import '../services/gemini_service.dart';
import '../services/pdf_service.dart';
import 'result_screen.dart';


class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  final GeminiService _geminiService = GeminiService();
  final PdfService _pdfService = PdfService();

  bool _isProcessing = false;
  String? _statusText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Scan Bill'),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status
          if (_isProcessing)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(_statusText ?? 'Processing...'),
                ],
              ),
            ),

          // Preview placeholder
          Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 100,
                  color: Colors.grey,
                ),
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        'Camera',
                        Icons.camera_alt,
                        () => _captureImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _actionButton(
                        'Gallery',
                        Icons.photo_library,
                        () => _captureImage(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _actionButton(
                  'PDF File',
                  Icons.picture_as_pdf,
                  _pickPdf,
                  color: const Color(0xFFD32F2F),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String title, IconData icon, VoidCallback onTap, {Color? color}) {
    return ElevatedButton.icon(
      onPressed: _isProcessing ? null : onTap,
      icon: Icon(icon),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? const Color(0xFF1D9E75),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _captureImage(ImageSource source) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusText = 'Capturing image...';
    });

    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null || !mounted) {
        _resetProcessing();
        return;
      }

      await _processImage(File(image.path));
    } catch (e) {
      if (mounted) {
        _showError('Capture failed: $e');
      }
      _resetProcessing();
    }
  }

  Future<void> _pickPdf() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusText = 'Selecting PDF...';
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || !mounted) {
        _resetProcessing();
        return;
      }

      final file = File(result.files.single.path!);
      await _processPdf(file);
    } catch (e) {
      if (mounted) {
        _showError('PDF selection failed: $e');
      }
      _resetProcessing();
    }
  }

  Future<void> _processImage(File imageFile) async {
    try {
      setState(() => _statusText = 'Extracting text with OCR...');

      final rawText = await _ocrService.extractText(imageFile);

      setState(() => _statusText = 'Parsing with AI...');

      final parsed = await _geminiService.parseBill(rawText);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              parsedData: parsed,
              imagePath: imageFile.path,
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Processing failed: $e');
    } finally {
      _resetProcessing();
    }
  }

  Future<void> _processPdf(File pdfFile) async {
    try {
      setState(() => _statusText = 'Extracting text from PDF...');

      final rawText = await _pdfService.extractTextFromPdf(pdfFile);

      setState(() => _statusText = 'Parsing with AI...');

      final parsed = await _geminiService.parseBill(rawText);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              parsedData: parsed,
              imagePath: pdfFile.path,  // Use PDF path for preview
            ),
          ),
        );
      }
    } catch (e) {
      _showError('PDF processing failed: $e');
    } finally {
      _resetProcessing();
    }
  }

  void _resetProcessing() {
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _statusText = null;
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


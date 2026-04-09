import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ocr_service.dart' as ocr;
import '../services/pdf_service.dart';
import '../screens/result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  TextRecognizer? _textRecognizer;

  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer?.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    // Future camera preview logic
  }

  /// 🔥 PROCESS FILE (NO ANIMATION)
  Future<void> _processImageFile(File file) async {
    setState(() => isScanning = true);

    final result = await ocr.OCRService.analyzeBill(file);

    if (!mounted) return;

    setState(() => isScanning = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          imagePath: file.path,
          merchant: result.merchant,
          amount: result.amountResult.amount,
          date: result.date,
          category: result.category,
          amountConfidence: result.amountResult.confidence,
          amountConfidenceLabel: result.amountResult.label,
          amountAlternatives: result.amountResult.alternatives,
          amountEvidence: result.amountResult.evidenceLine,
          amountReasons: result.amountResult.reasons,
          gstBreakdown: result.gstBreakdown,
          items: result.items,
          blocks: result.blocks,
        ),
      ),
    );
  }

  /// 📸 CAMERA
  Future<void> scanCamera(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? file =
        await picker.pickImage(source: ImageSource.camera);

    if (file == null) return;

    await _processImageFile(File(file.path));
  }

  /// 🖼 IMAGE
  Future<void> pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? file =
        await picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    await _processImageFile(File(file.path));
  }

  /// 📄 PDF
  Future<void> pickPDF(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null) return;

    final pdfFile = File(result.files.single.path!);

    final imageFile =
        await PDFService.convertFirstPageToImage(pdfFile.path);

    if (imageFile == null) {
      if (!mounted) return;

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to extract PDF page')),
      );
      return;
    }

    await _processImageFile(imageFile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Bill"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// 🔥 HERO CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF1D9E75), Color(0xFF146B59)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.document_scanner,
                    size: 40, color: Colors.white70),
                SizedBox(height: 16),
                Text(
                  "Capture receipts your way",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Scan from camera, gallery, or PDF.",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _buildOptionCard(
            icon: Icons.camera_alt,
            color: Colors.green,
            title: "Scan with Camera",
            subtitle: "Fastest OCR flow",
            onTap: () => scanCamera(context),
          ),

          _buildOptionCard(
            icon: Icons.image,
            color: Colors.blue,
            title: "Upload Image",
            subtitle: "Pick from gallery",
            onTap: () => pickImage(context),
          ),

          _buildOptionCard(
            icon: Icons.picture_as_pdf,
            color: Colors.orange,
            title: "Upload PDF",
            subtitle: "Extract first page",
            onTap: () => pickPDF(context),
          ),

          const SizedBox(height: 20),

          /// ℹ️ INFO
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              // ignore: deprecated_member_use
              color: Colors.white.withOpacity(0.05),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("What happens next",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text("• OCR extracts text"),
                Text("• AI detects totals"),
                Text("• You confirm & save"),
              ],
            ),
          )
        ],
      ),
    );
  }

  /// 🔥 CARD UI
  Widget _buildOptionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // ignore: deprecated_member_use
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}


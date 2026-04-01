import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> extractText(File file) async {
    try {
      final inputImage = InputImage.fromFilePath(file.path);

      final result = await _recognizer.processImage(inputImage);

      final buffer = StringBuffer();

      for (final block in result.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
      }

      final cleaned = _advancedClean(buffer.toString());

      if (cleaned.isEmpty) {
        throw Exception("No readable text found.");
      }

      return cleaned;
    } catch (e) {
      throw Exception("OCR failed: $e");
    } finally {
      await _recognizer.close();
    }
  }

  //  ADVANCED CLEANING
  String _advancedClean(String text) {
    final lines = text.split('\n');

    final filtered = lines.where((line) {
      final l = line.trim();

      if (l.isEmpty) return false;

      // remove status bar junk
      if (RegExp(r'\d{1,2}:\d{2}').hasMatch(l)) return false;
      if (l.contains('KB/s') || l.contains('VoLTE')) return false;

      return true;
    }).toList();

    return filtered.join('\n').trim();
  }
}
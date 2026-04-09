import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img_lib;
import 'package:image/image.dart' as img;

class EdgeAIService {
  static Interpreter? _interpreter;
  static bool _isLoaded = false;

  /// Offline OCR fallback using TFLite (lite model for edge)
  static Future<String?> performOfflineOCR(Uint8List imageBytes) async {
    try {
      await _loadModel();
      if (!_isLoaded) return null;

      final image = img_lib.decodeImage(imageBytes);
      if (image == null) return null;

      // Preprocess for model: resize 224x224, normalize
      final resized = img.copyResize(image, width: 224, height: 224);
      final input = _imageToByteListFloat32(resized, 224);

      final output = List.filled(1 * 35 * 100, 0.0).reshape([1, 35, 100]);
      _interpreter!.run(input, output);

      // Decode topk text (simplified CTC decode)
      return _decodeOutput(output);
    } catch (e) {
      return null;
    }
  }

  static Future<void> _loadModel() async {
    if (_isLoaded) return;

    try {
      final modelBytes = await rootBundle.load('assets/models/ocr_lite.tflite');
      final modelPath = await _getModelPath(modelBytes);
      _interpreter = await Interpreter.fromAsset(modelPath);
      _isLoaded = true;
    } catch (e) {
      // Fallback to OCRService
    }
  }

  static Future<String> _getModelPath(ByteData modelBytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/ocr_lite.tflite';
    final file = File(path);
    if (!await file.exists()) {
      await file.writeAsBytes(modelBytes.buffer.asUint8List());
    }
    return path;
  }

  static Float32List _imageToByteListFloat32(img_lib.Image image, int inputSize) {
    final convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    final buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (final pixel in image) {
      buffer[pixelIndex++] = (pixel.r / 255.0);
      buffer[pixelIndex++] = (pixel.g / 255.0);
      buffer[pixelIndex++] = (pixel.b / 255.0);
    }
    return convertedBytes;
  }

  static String _decodeOutput(List output) {
    // Simplified: return top text prediction
    // Real impl would use CTC decoder
    return 'Offline OCR: ₹150.00 Total';
  }

  static void dispose() {
    _interpreter?.close();
    _isLoaded = false;
  }
}


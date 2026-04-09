import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Copy image/video file to persistent app documents directory
/// Returns persistent File path or null on error
Future<String?> copyToPersistentStorage(String tempPath, {String? extension}) async {
  try {
    final tempFile = File(tempPath);
    if (!await tempFile.exists()) return null;

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = extension ?? path.extension(tempPath).toLowerCase();
    final filename = 'bill_$timestamp$ext';
    final persistentFile = File(path.join(dir.path, filename));

    // Copy file
    await tempFile.copy(persistentFile.path);

    // Compress image if JPG/PNG (for storage efficiency)
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png') {
      final bytes = await persistentFile.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1200,
        minHeight: 1200,
        quality: 85,
      );
      await persistentFile.writeAsBytes(compressed);
    }

    return persistentFile.path;
  } catch (e) {
    debugPrint('File copy error: $e');
    return null;
  }
}

/// Request media permissions (camera, storage, photos)
Future<bool> requestMediaPermissions() async {
  // Implementation depends on permission_handler
  // Add to scanner_screen: import 'package:permission_handler/permission_handler.dart';
  // Then call Permission.camera.request(), etc.
  return true; // Placeholder - implement in UI
}


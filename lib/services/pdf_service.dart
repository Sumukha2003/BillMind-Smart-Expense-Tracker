import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render_plus/pdf_render.dart';

class PDFService {
  static Future<File?> convertFirstPageToImage(String pdfPath) async {
    PdfDocument? doc;
    PdfPageImage? pageImage;

    try {
      doc = await PdfDocument.openFile(pdfPath);
      final page = await doc.getPage(1);
      const scale = 1.5; // Faster render (80% size, same OCR accuracy)
      final renderWidth = (page.width * scale).round().clamp(800, 1600);
      final renderHeight = (page.height * scale).round().clamp(800, 1600);

      pageImage = await page.render(
        width: renderWidth,
        height: renderHeight,
      );

      final image = await pageImage.createImageDetached();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File(
        path.join(
          tempDir.path,
          'pdf_page_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      return file;
    } catch (e) {
      return null;
    } finally {
      pageImage?.dispose();
      await doc?.dispose();
    }
  }
}

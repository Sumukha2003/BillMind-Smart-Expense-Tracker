import 'dart:io';
import 'dart:ui' as ui;
import 'package:pdf_render_plus/pdf_render.dart';

class PDFService {
  static Future<File?> convertFirstPageToImage(String path) async {
    PdfDocument? doc;
    PdfPageImage? pageImage;

    try {
      doc = await PdfDocument.openFile(path);
      final page = await doc.getPage(1);

      pageImage = await page.render(
        width: page.width.toInt(),
        height: page.height.toInt(),
      );

      final image = await pageImage.createImageDetached();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return null;
      }

      final file = File('${path}_page1.png');
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

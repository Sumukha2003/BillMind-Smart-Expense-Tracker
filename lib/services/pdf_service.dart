import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfService {
  Future<String> extractTextFromPdf(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      String text = '';

      for (int i = 0; i < document.pages.count; i++) {
        final pageText = PdfTextExtractor(document)
            .extractText(startPageIndex: i, endPageIndex: i);

        text += "$pageText\n";
      }

      document.dispose();

      if (text.trim().isEmpty) {
        throw Exception("No readable text in PDF");
      }

      return text;
    } catch (e) {
      throw Exception("PDF text extraction failed: $e");
    }
  }
}
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class OCRBlock {
  final String text;
  final ui.Rect rect;

  OCRBlock(this.text, this.rect);
}

class OCRPainter extends CustomPainter {
  final List<OCRBlock> blocks;
  final String? highlightText;

  const OCRPainter({
    required this.blocks,
    this.highlightText,
  });

  static const Color normalColor = Color.fromARGB(102, 76, 175, 80);
  static const Color highlightColor = Color.fromARGB(153, 76, 175, 80);

  @override
  void paint(ui.Canvas canvas, Size size) {
    final normalPaint = Paint()
      ..color = normalColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final highlightPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    for (var block in blocks) {
      final paint = (highlightText != null && block.text.toLowerCase().contains(highlightText!.toLowerCase()))
          ? highlightPaint
          : normalPaint;
      canvas.drawRect(block.rect, paint);
    }
  }

  @override
  bool shouldRepaint(OCRPainter oldDelegate) => true;
}

import 'package:flutter_test/flutter_test.dart';

import 'package:bill_scanner_app/services/ocr_service.dart';

void main() {
  group('OCRService.extractAmountDetails', () {
    test('prefers total keyword over small noise values', () {
      const text = '''
DAYANANDA SAGAR UNIVERSITY
Receipt No 123456
Academic Fee 33,000
Tuition Fee 57,750
TOTAL: 99,791
Round Off 3.00
''';

      final result = OCRService.extractAmountDetails(text);

      expect(result.amount, 99791);
      expect(result.confidence, greaterThan(0.55));
    });

    test('ignores percentages dates and references when selecting amount', () {
      const text = '''
Invoice No: 2025-09-17
Date: 17-09-2025
CGST 9%
SGST 9%
Amount Payable Rs 4,560.00
''';

      final result = OCRService.extractAmountDetails(text);

      expect(result.amount, 4560);
    });

    test('prefers totals near the bottom of the bill', () {
      const text = '''
Item 1 9000
Item 2 9000
Subtotal 18000
Discount 100
Net Amount 17900
''';

      final result = OCRService.extractAmountDetails(text);

      expect(result.amount, 17900);
      expect(result.label, isNotEmpty);
    });
  });
}

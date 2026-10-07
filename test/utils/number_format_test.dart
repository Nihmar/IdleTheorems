import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/utils/number_format.dart';

void main() {
  group('formatNumber', () {
    test('small integers stay plain', () {
      expect(formatNumber(0), '0');
      expect(formatNumber(42), '42');
      expect(formatNumber(999), '999');
    });

    test('small decimals keep at most two digits without trailing zeros', () {
      expect(formatNumber(0.5), '0.5');
      expect(formatNumber(1.256), '1.26');
      expect(formatNumber(12.5), '12.5');
    });

    test('suffix tiers scale by thousands', () {
      expect(formatNumber(1_234), '1.23K');
      expect(formatNumber(5e6), '5M');
      expect(formatNumber(1.5e12), '1.5T');
    });

    test('negative values carry the sign', () {
      expect(formatNumber(-1234), '-1.23K');
    });

    test('NaN and infinity render as the infinity glyph', () {
      expect(formatNumber(double.nan), '\u221e');
      expect(formatNumber(double.infinity), '\u221e');
    });

    test('values beyond the last named tier use scientific notation', () {
      final s = formatNumber(1e78);
      expect(s.contains('e'), isTrue);
    });
  });

  group('formatRate', () {
    test('appends /s to the formatted magnitude', () {
      expect(formatRate(0), '0/s');
      expect(formatRate(12.5), '12.5/s');
      expect(formatRate(1_234), '1.23K/s');
      expect(formatRate(5e6), '5M/s');
    });
  });
}

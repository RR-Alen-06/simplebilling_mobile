import 'package:flutter_test/flutter_test.dart';
import 'package:simplebilling_mobile/core/utils/rounding_engine.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';

void main() {
  group('POS Rounding & Calculation Engine Tests', () {
    test('Round Down calculates properly', () {
      final res = RoundingEngine.calculate(154.75, RoundingMethod.roundDown);
      expect(res.roundedTotal, 154.0);
      expect(res.roundingAdjustment, -0.75);
    });

    test('Round Up calculates properly', () {
      final res = RoundingEngine.calculate(154.20, RoundingMethod.roundUp);
      expect(res.roundedTotal, 155.0);
      expect(res.roundingAdjustment, 0.80);
    });

    test('Standard rounding calculates properly', () {
      final res1 = RoundingEngine.calculate(154.49, RoundingMethod.standard);
      expect(res1.roundedTotal, 154.0);

      final res2 = RoundingEngine.calculate(154.50, RoundingMethod.standard);
      expect(res2.roundedTotal, 155.0);
    });

    test('Currency formatters output in correct format', () {
      final str = Formatters.currency(250.5);
      expect(str, '₹ 250.50');
    });
  });
}

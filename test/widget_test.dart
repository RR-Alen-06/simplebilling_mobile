import 'package:flutter_test/flutter_test.dart';
import 'package:simplebilling_mobile/core/utils/rounding_engine.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';

void main() {
  testWidgets('App basic smoke test', (WidgetTester tester) async {
    final result = RoundingEngine.calculate(100.25, RoundingMethod.roundUp);
    expect(result.roundedTotal, 101.0);

    final curr = Formatters.currency(100.0);
    expect(curr, '₹ 100.00');
  });
}

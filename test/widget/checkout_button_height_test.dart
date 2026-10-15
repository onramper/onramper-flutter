import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/src/widget/checkout_button_height.dart';

void main() {
  test('starts at fallback, adopts reported heights', () {
    final c = CheckoutButtonHeightController();
    expect(c.height, CheckoutButtonHeightController.fallbackHeight);
    c.onHeightChanged(92);
    expect(c.height, 92);
  });

  test('ignores zero/negative and unchanged heights without notifying', () {
    final c = CheckoutButtonHeightController();
    var n = 0;
    c.addListener(() => n++);
    c.onHeightChanged(0);
    c.onHeightChanged(-1);
    c.onHeightChanged(80);
    c.onHeightChanged(80);
    expect(c.height, 80);
    expect(n, 1);
  });

  test('minHeight is a floor', () {
    final c = CheckoutButtonHeightController(minHeight: 70)
      ..onHeightChanged(50);
    expect(c.height, 70);
  });

  test('onUnavailable collapses to zero', () {
    final c = CheckoutButtonHeightController()..onHeightChanged(80);
    c.onUnavailable();
    expect(c.isUnavailable, isTrue);
    expect(c.height, 0);
  });
}

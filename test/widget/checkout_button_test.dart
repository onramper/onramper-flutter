// Tests for OnramperCheckoutButton.
//
// The widget no longer accepts a `client` parameter and no longer invokes
// `presentCheckout`. It renders only an OnramperNativeCheckoutButton
// (UiKitView on iOS, empty SizedBox on other platforms); the native button
// draws the ToS sentence itself.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

void main() {
  // Helper: build a minimal CheckoutRequirementsResult for tests.
  CheckoutRequirementsResult fixtureRequirements({
    List<CheckoutRequirement>? requirements,
    String buttonHandle = 'test-handle',
  }) =>
      CheckoutRequirementsResult(
        headlessCheckoutId: 'co_1',
        requirements: requirements ?? const [],
        quote: const QuoteResponse(
          quoteId: 'q',
          ramp: 'moonpay',
          rate: 0.000017,
          networkFee: 0,
          transactionFee: 0,
          payout: 0.000017,
          paymentMethod: 'credit_debit_card',
        ),
        buttonHandle: buttonHandle,
      );

  testWidgets(
      'renders OnramperNativeCheckoutButton with no ToS when none provided',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OnramperCheckoutButton(
          requirements: fixtureRequirements(),
        ),
      ),
    ));

    // The native button widget should be present in the tree.
    expect(find.byType(OnramperNativeCheckoutButton), findsOneWidget);
  });

  testWidgets('unsatisfied ToS items are left to the native button',
      (tester) async {
    const tos = TosRequirement(
      providerId: 'transak',
      items: [
        TosItem(
          type: TosItemType.tos,
          required: true,
          satisfied: false,
          url: 'https://example.com/tos',
          content: 'Terms of Service',
        ),
      ],
    );
    final reqs = fixtureRequirements(requirements: const [
      CheckoutRequirement(kind: CheckoutRequirementKind.tos, tos: tos),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OnramperCheckoutButton(requirements: reqs),
      ),
    ));

    // Dart-side lines would duplicate the native consent sentence.
    expect(find.textContaining('Terms of Service'), findsNothing);
    expect(find.byType(OnramperNativeCheckoutButton), findsOneWidget);
  });

  testWidgets('button handle is forwarded to OnramperNativeCheckoutButton',
      (tester) async {
    const handle = 'uuid-abc-123';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OnramperCheckoutButton(
          requirements: fixtureRequirements(buttonHandle: handle),
        ),
      ),
    ));

    final nativeBtn = tester.widget<OnramperNativeCheckoutButton>(
      find.byType(OnramperNativeCheckoutButton),
    );
    expect(nativeBtn.buttonHandle, handle);
  });
}

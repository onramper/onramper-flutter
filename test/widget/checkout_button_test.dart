// Tests for OnramperCheckoutButton.
//
// The widget no longer accepts a `client` parameter and no longer invokes
// `presentCheckout`. It renders an OnramperNativeCheckoutButton (UiKitView on
// iOS, empty SizedBox on other platforms) above any unsatisfied ToS lines.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_sdk/onramper_sdk.dart';

void main() {
  // Helper: build a minimal CheckoutRequirementsResult for tests.
  CheckoutRequirementsResult fixtureRequirements({
    List<CheckoutRequirement>? requirements,
    String buttonHandle = 'test-handle',
  }) =>
      CheckoutRequirementsResult(
        headlessCheckoutId: 'co_1',
        requirements: requirements ?? const [],
        quote: const QuoteResponse(rate: 0.000017),
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
    // No ToS lines — only the native button column.
    expect(find.byType(Column), findsWidgets);
  });

  testWidgets('ToS items render with link text', (tester) async {
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
        TosItem(
          type: TosItemType.privacyPolicy,
          required: true,
          satisfied: false,
          url: 'https://example.com/privacy',
          content: 'Privacy Policy',
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

    expect(find.textContaining('Terms of Service'), findsOneWidget);
    expect(find.textContaining('Privacy Policy'), findsOneWidget);
  });

  testWidgets('satisfied ToS items are not rendered', (tester) async {
    const tos = TosRequirement(
      providerId: 'transak',
      items: [
        TosItem(
          type: TosItemType.tos,
          required: true,
          satisfied: true, // already satisfied — should not appear
          url: 'https://example.com/tos',
        ),
        TosItem(
          type: TosItemType.privacyPolicy,
          required: true,
          satisfied: false, // unsatisfied — should appear
          url: 'https://example.com/privacy',
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

    expect(find.textContaining('Terms of Service'), findsNothing);
    expect(find.textContaining('Privacy Policy'), findsOneWidget);
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

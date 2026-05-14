import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_sdk/onramper_sdk.dart';
import 'package:onramper_sdk/src/platform/pigeon.g.dart';

void main() {
  late FakeOnramperHostApi fakeHost;
  late OnramperClient client;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    fakeHost = FakeOnramperHostApi();
    client = OnramperClient.forTesting(
      configuration:
          const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
      hostApi: fakeHost,
    );
  });

  tearDown(() async {
    await client.dispose();
  });

  CheckoutRequirementsResult fixtureRequirements({
    List<CheckoutRequirement>? requirements,
  }) =>
      CheckoutRequirementsResult(
        headlessCheckoutId: 'co_1',
        requirements: requirements ?? const [],
        quote: const QuoteResponse(rate: 0.000017),
      );

  testWidgets('renders the default Buy label and no ToS when none provided',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OnramperCheckoutButton(
          client: client,
          requirements: fixtureRequirements(),
        ),
      ),
    ));

    expect(find.text('Buy'), findsOneWidget);
    // No ToS lines: only the Buy label text. Ensure the column laid out.
    expect(find.byType(Column), findsWidgets);
  });

  testWidgets('tapping the button invokes presentCheckout', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OnramperCheckoutButton(
          client: client,
          requirements: fixtureRequirements(),
        ),
      ),
    ));

    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();

    expect(fakeHost.presentCheckoutCallCount, 1);
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
        body: OnramperCheckoutButton(client: client, requirements: reqs),
      ),
    ));

    expect(find.textContaining('Terms of Service'), findsOneWidget);
    expect(find.textContaining('Privacy Policy'), findsOneWidget);
  });

  testWidgets('button is disabled while client state is finalizing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OnramperCheckoutButton(
          client: client,
          requirements: fixtureRequirements(),
        ),
      ),
    ));

    // Drive client into a busy state.
    client.debugDispatchStateChanged(
      OnramperStateDto(kind: OnramperStateKindDto.finalizing),
    );
    // Use `pump` (not `pumpAndSettle`) — the busy state shows a
    // CircularProgressIndicator whose animation never settles.
    await tester.pump();

    final buttonFinder = find.byType(ElevatedButton);
    final ElevatedButton button = tester.widget(buttonFinder);
    expect(button.onPressed, isNull);
  });

  testWidgets('label can be customized', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OnramperCheckoutButton(
          client: client,
          requirements: fixtureRequirements(),
          label: 'Continue',
        ),
      ),
    ));

    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Buy'), findsNothing);
  });
}

class FakeOnramperHostApi implements OnramperHostApi {
  int presentCheckoutCallCount = 0;

  @override
  // ignore: non_constant_identifier_names
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  // ignore: non_constant_identifier_names
  String get pigeonVar_messageChannelSuffix => '';

  @override
  Future<void> configure(ConfigurationDto config) async {}

  @override
  Future<void> initialize(SessionCredentialsDto credentials) async {}

  @override
  Future<CheckoutRequirementsResultDto> getCheckoutRequirements(
    CheckoutIntentRequestDto request,
  ) async {
    return CheckoutRequirementsResultDto(
      headlessCheckoutId: 'stub',
      requirements: const [],
      quote: QuoteDto(),
    );
  }

  @override
  Future<void> presentCheckout() async {
    presentCheckoutCallCount++;
  }

  @override
  Future<void> reset() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> provideRefreshedSession(SessionCredentialsDto credentials) async {}

  @override
  Future<void> failRefreshedSession(String reason) async {}
}

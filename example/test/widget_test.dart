import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter/src/platform/pigeon.g.dart';

import 'package:onramper_flutter_example/main.dart';

void main() {
  testWidgets('ExampleApp renders the home scaffold', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Onramper SDK example'), findsOneWidget);
  });

  testWidgets('editing purchase details removes the previous checkout',
      (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var preparation = 0;
    for (final method in [
      'configure',
      'initialize',
      'getCheckoutRequirements',
      'sdkVersion',
      'dispose',
    ]) {
      final channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.onramper_flutter.OnramperHostApi.$method',
        OnramperHostApi.pigeonChannelCodec,
      );
      messenger.setMockDecodedMessageHandler<Object?>(channel, (_) async {
        if (method == 'sdkVersion') return ['1.3.1'];
        if (method == 'getCheckoutRequirements') {
          return [
            CheckoutRequirementsResultDto(
              headlessCheckoutId: 'checkout-${++preparation}',
              buttonHandle: 'button-$preparation',
              requirements: [],
              quote: QuoteDto(
                quoteId: 'quote-$preparation',
                ramp: 'moonpay',
                rate: 1,
                networkFee: 0,
                transactionFee: 0,
                payout: 100,
                paymentMethod: 'applepay',
              ),
            ),
          ];
        }
        return <Object?>[];
      });
      addTearDown(
          () => messenger.setMockDecodedMessageHandler<Object?>(channel, null));
    }
    final darkMode = ValueNotifier(false);
    addTearDown(darkMode.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ExampleHome(
        darkMode: darkMode,
        sessionCredentialsProvider: () async => const SessionCredentials(
          sessionId: 'session',
          sessionToken: 'token',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    for (final field in ['amount', 'wallet', 'crypto']) {
      final prepare = find.widgetWithText(ElevatedButton, 'Prepare checkout');
      await tester.ensureVisible(prepare);
      await tester.tap(prepare);
      await tester.pumpAndSettle();
      expect(find.byType(OnramperCheckoutButton), findsOneWidget);

      if (field == 'crypto') {
        await tester.ensureVisible(find.text('BTC'));
        await tester.tap(find.text('BTC'));
      } else {
        final input = find.byType(TextField).at(field == 'amount' ? 0 : 1);
        await tester.ensureVisible(input);
        await tester.enterText(input, field == 'amount' ? '250' : 'new-wallet');
      }
      await tester.pumpAndSettle();
      expect(find.byType(OnramperCheckoutButton), findsNothing,
          reason: 'An edited $field must not leave the old purchase active');
      expect(prepare, findsOneWidget);
      expect(find.textContaining('ready — tap Buy'), findsNothing);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

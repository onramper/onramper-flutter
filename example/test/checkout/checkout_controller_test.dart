import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter_example/checkout/checkout_controller.dart';
import 'package:onramper_flutter_example/checkout/prefill.dart';
import 'package:onramper_flutter_example/checkout/request.dart';
import 'package:onramper_flutter_example/theme/demo_theme.dart';

import '../support/fake_host.dart';

Future<void> settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

OnramperClient client(FakeHost host) => OnramperClient.forTesting(
      configuration: const OnramperConfiguration(apiKey: 'k', clientId: 'c'),
      hostApi: host,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> log;
  late CheckoutController checkout;
  setUp(() {
    log = [];
    checkout = CheckoutController(
        log: (level, line) => log.add('${level.name}: $line'));
  });

  void update(OnramperClient? c,
          {BuyForm form = const BuyForm(),
          PrefillInput prefill = const PrefillInput()}) =>
      checkout.update(
          client: c, form: form, prefill: prefill, palette: DemoPalette.dark);

  test('no client or invalid form means idle', () async {
    update(null);
    expect(checkout.loading, isFalse);
    final host = FakeHost();
    update(client(host), form: const BuyForm(amount: '0'));
    await settle();
    expect(host.requirementsCalls, 0);
    expect(checkout.result, isNull);
  });

  test('requests with button style and logs RN lines', () async {
    final host = FakeHost();
    update(client(host));
    expect(checkout.loading, isTrue);
    await settle();
    expect(checkout.loading, isFalse);
    expect(checkout.result?.quote.ramp, 'moonpay');
    expect(host.lastButtonStyle, isNotNull);
    expect(log, [
      'info: quote: 100 USD → SOL via applepay',
      'info: Sends: nothing',
      'info: quote ok: moonpay rate=50000.0 payout=0.002',
    ]);
  });

  test('identical inputs do not re-request; refresh does', () async {
    final host = FakeHost();
    final c = client(host);
    update(c);
    await settle();
    update(c, form: const BuyForm());
    await settle();
    expect(host.requirementsCalls, 1);
    checkout.refresh();
    await settle();
    expect(host.requirementsCalls, 2);
  });

  test('stale response is dropped', () async {
    final host = FakeHost();
    final first = Completer<void>();
    host.requirementsGates.addAll([first, Completer<void>()..complete()]);
    final c = client(host);
    update(c);
    await settle();
    update(c, form: const BuyForm(amount: '250'));
    await settle();
    expect(checkout.result?.headlessCheckoutId, 'checkout-2');
    first.complete();
    await settle();
    expect(checkout.result?.headlessCheckoutId, 'checkout-2');
  });

  test('amountOutOfRange becomes the amount hint; other errors become error',
      () async {
    final host = FakeHost()
      ..requirementsError = const OnramperError(
        kind: OnramperErrorKind.amountOutOfRange,
        message: 'raw',
        recoverable: true,
        userMessage: 'Minimum is 20 USD',
      );
    update(client(host));
    await settle();
    expect(checkout.amountHint,
        'Minimum is 20 USD\nError code: FLUTTER-UNSPECIFIED');
    expect(checkout.error, isNull);
    expect(log.last,
        'error: quote failed: amountOutOfRange — Minimum is 20 USD\nError code: FLUTTER-UNSPECIFIED');

    host.requirementsError = const OnramperError(
      kind: OnramperErrorKind.quoteUnavailable,
      message: 'raw',
      recoverable: true,
      userMessage: 'No quotes',
    );
    checkout.refresh();
    expect(checkout.amountHint, isNull);
    await settle();
    expect(checkout.error,
        'quoteUnavailable — No quotes\nError code: FLUTTER-UNSPECIFIED');
  });

  test('a result is hidden once the client changes', () async {
    final host = FakeHost();
    update(client(host));
    await settle();
    expect(checkout.result, isNotNull);
    update(null);
    expect(checkout.result, isNull);
  });
}

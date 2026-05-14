import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_sdk/onramper_sdk.dart';
import 'package:onramper_sdk/src/platform/pigeon.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnramperClient', () {
    test('configure() forwards via HostApi', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration: const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );
      // configure is fire-and-forget in the constructor; wait for the microtask.
      await Future<void>.delayed(Duration.zero);
      expect(fakeHost.configureCallCount, 1);
      expect(fakeHost.lastConfigDto?.apiKey, 'pk_x');
      await client.dispose();
    });

    test('onStateChanged updates state, stateStream, notifyListeners', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration: const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );

      var notifyCount = 0;
      client.addListener(() => notifyCount++);
      final received = <OnramperState>[];
      final sub = client.stateStream.listen(received.add);

      client.debugDispatchStateChanged(OnramperStateDto(kind: OnramperStateKindDto.ready));
      await Future<void>.delayed(Duration.zero);

      expect(client.state.kind, OnramperStateKind.ready);
      expect(received.single.kind, OnramperStateKind.ready);
      expect(notifyCount, 1);

      await sub.cancel();
      await client.dispose();
    });

    test('initialize forwards credentials to HostApi', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration: const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );
      await client.initialize(sessionId: 'sess', sessionToken: 'tok');
      expect(fakeHost.lastInitializeCredentials?.sessionId, 'sess');
      expect(fakeHost.lastInitializeCredentials?.sessionToken, 'tok');
      await client.dispose();
    });

    test('getCheckoutRequirements returns mapped result', () async {
      final fakeHost = FakeOnramperHostApi()
        ..nextRequirementsResult = CheckoutRequirementsResultDto(
          headlessCheckoutId: 'co_123',
          requirements: const [],
          quote: QuoteDto(rate: 0.000017, payout: 0.000017),
        );
      final client = OnramperClient.forTesting(
        configuration: const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );
      final result = await client.getCheckoutRequirements(const CheckoutIntentRequest(
        transactionData: OnramperTransactionData(
          onramp: 'transak', source: 'usd', amount: 100, type: TransactionType.buy,
          paymentMethod: 'credit_debit_card',
          wallet: WalletInfo(network: 'bitcoin', address: 'bc1q...'),
        ),
      ));
      expect(result.headlessCheckoutId, 'co_123');
      expect(client.tosRequirements, isEmpty);
      await client.dispose();
    });

    test('onEvent fans out to events stream', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration: const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );
      final received = <CheckoutEvent>[];
      final sub = client.events.listen(received.add);

      client.debugDispatchEvent(CheckoutEventDto(
        kind: CheckoutEventKindDto.checkoutStarted,
        checkoutId: 'co_999',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(received.single.kind, CheckoutEventKind.checkoutStarted);
      expect(received.single.checkoutId, 'co_999');

      await sub.cancel();
      await client.dispose();
    });

    test('onError updates lastError and notifies listeners', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration: const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );
      var notified = 0;
      client.addListener(() => notified++);

      client.debugDispatchError(OnramperErrorDto(
        kind: OnramperErrorKindDto.timeout,
        message: 'gateway timeout',
        recoverable: true,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(client.lastError?.kind, OnramperErrorKind.timeout);
      expect(notified, 1);
      await client.dispose();
    });

    test('onSessionExpired invokes the configured handler', () async {
      var handlerCalls = 0;
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration: const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
        sessionExpirationHandler: () async {
          handlerCalls++;
          return const SessionCredentials(sessionId: 'new', sessionToken: 'newTok');
        },
      );

      await client.debugDispatchSessionExpired();
      expect(handlerCalls, 1);
      expect(fakeHost.lastProvidedCredentials?.sessionId, 'new');
      await client.dispose();
    });

    test('onSessionExpired without handler calls failRefreshedSession', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration: const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );

      await client.debugDispatchSessionExpired();
      expect(fakeHost.lastFailReason, isNotNull);
      await client.dispose();
    });

    test('dispose closes streams', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration: const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );
      await client.dispose();
      expect(fakeHost.disposeCallCount, 1);
    });
  });
}

class FakeOnramperHostApi implements OnramperHostApi {
  int configureCallCount = 0;
  int disposeCallCount = 0;
  ConfigurationDto? lastConfigDto;
  SessionCredentialsDto? lastInitializeCredentials;
  CheckoutRequirementsResultDto? nextRequirementsResult;
  SessionCredentialsDto? lastProvidedCredentials;
  String? lastFailReason;

  @override
  // ignore: non_constant_identifier_names
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  // ignore: non_constant_identifier_names
  String get pigeonVar_messageChannelSuffix => '';

  @override
  Future<void> configure(ConfigurationDto config) async {
    configureCallCount++;
    lastConfigDto = config;
  }

  @override
  Future<void> initialize(SessionCredentialsDto credentials) async {
    lastInitializeCredentials = credentials;
  }

  @override
  Future<CheckoutRequirementsResultDto> getCheckoutRequirements(CheckoutIntentRequestDto request) async {
    return nextRequirementsResult ??
        CheckoutRequirementsResultDto(
          headlessCheckoutId: 'stub',
          requirements: const [],
          quote: QuoteDto(),
        );
  }

  @override
  Future<void> presentCheckout() async {}

  @override
  Future<void> reset() async {}

  @override
  Future<void> dispose() async {
    disposeCallCount++;
  }

  @override
  Future<void> provideRefreshedSession(SessionCredentialsDto credentials) async {
    lastProvidedCredentials = credentials;
  }

  @override
  Future<void> failRefreshedSession(String reason) async {
    lastFailReason = reason;
  }
}

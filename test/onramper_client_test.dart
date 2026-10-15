import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter/src/platform/pigeon.g.dart';

QuoteDto _sampleQuoteDto() => QuoteDto(
      quoteId: 'q-stub',
      ramp: 'moonpay',
      rate: 0.000017,
      networkFee: 0,
      transactionFee: 0,
      payout: 0.000017,
      paymentMethod: 'credit_debit_card',
    );

CheckoutIntentRequest _sampleRequest() => const CheckoutIntentRequest(
      transactionData: OnramperTransactionData(
        source: 'usd',
        destination: 'btc',
        amount: 100,
        type: TransactionType.buy,
        paymentMethod: 'credit_debit_card',
        wallet: WalletInfo(network: 'bitcoin', address: 'bc1q...'),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnramperClient', () {
    test('configure() forwards via HostApi', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );
      await Future<void>.delayed(Duration.zero);
      expect(fakeHost.configureCallCount, 1);
      expect(fakeHost.lastConfigDto?.apiKey, 'pk_x');
      await client.dispose();
    });

    test('onStateChanged updates state, stateStream, notifyListeners',
        () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );

      var notifyCount = 0;
      client.addListener(() => notifyCount++);
      final received = <OnramperState>[];
      final sub = client.stateStream.listen(received.add);

      client.debugDispatchStateChanged(
          OnramperStateDto(kind: OnramperStateKindDto.ready));
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
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
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
          quote: _sampleQuoteDto(),
          buttonHandle: 'btn-handle-1',
        );
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );
      final result =
          await client.getCheckoutRequirements(const CheckoutIntentRequest(
        transactionData: OnramperTransactionData(
          source: 'usd',
          destination: 'btc',
          amount: 100,
          type: TransactionType.buy,
          paymentMethod: 'credit_debit_card',
          wallet: WalletInfo(network: 'bitcoin', address: 'bc1q...'),
        ),
      ));
      expect(result.headlessCheckoutId, 'co_123');
      expect(client.tosRequirements, isEmpty);
      await client.dispose();
    });

    test('currentTransactionId mirrors native and notifies once per change',
        () async {
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: FakeOnramperHostApi(),
      );
      var notifications = 0;
      client.addListener(() => notifications++);

      expect(client.currentTransactionId, isNull);
      client.onTransactionIdChanged('01JTXN');
      client.onTransactionIdChanged('01JTXN');
      expect(client.currentTransactionId, '01JTXN');
      expect(notifications, 1);

      await client.reset();
      expect(client.currentTransactionId, isNull);
      await client.dispose();
    });

    test('getCheckoutRequirements forwards prefill', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );
      await client.getCheckoutRequirements(
        _sampleRequest(),
        prefill: const OnramperUserPrefill(firstName: 'Ada'),
      );
      expect(fakeHost.lastPrefillDto?.firstName, 'Ada');

      await client.getCheckoutRequirements(_sampleRequest());
      expect(fakeHost.lastPrefillDto, isNull);
      await client.dispose();
    });

    test('getCheckoutRequirements forwards buttonStyle to host api', () async {
      final fakeHost = FakeOnramperHostApi()
        ..nextRequirementsResult = CheckoutRequirementsResultDto(
          headlessCheckoutId: 'co_s',
          requirements: const [],
          quote: _sampleQuoteDto(),
          buttonHandle: 'b',
        );
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );
      await client.getCheckoutRequirements(
        const CheckoutIntentRequest(
          transactionData: OnramperTransactionData(
            source: 'usd',
            destination: 'btc',
            amount: 100,
            type: TransactionType.buy,
            paymentMethod: 'credit_debit_card',
            wallet: WalletInfo(network: 'bitcoin', address: 'bc1q...'),
          ),
        ),
        buttonStyle: const CheckoutButtonStyle(
          backgroundColor: Color(0xff112233),
          borderRadius: 24,
        ),
      );
      expect(fakeHost.lastButtonStyleDto, isNotNull);
      expect(fakeHost.lastButtonStyleDto?.backgroundColor,
          matches(r'^#(?:112233|112233ff)$'));
      expect(fakeHost.lastButtonStyleDto?.borderRadius, 24);
      await client.dispose();
    });

    test('signOut forwards to host api', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );
      await client.signOut();
      expect(fakeHost.signOutCallCount, 1);
      await client.dispose();
    });

    test('cancelPreparedIntent forwards handle to host api', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );
      await client.cancelPreparedIntent('handle-42');
      expect(fakeHost.lastCancelledHandle, 'handle-42');
      await client.dispose();
    });

    test('onEvent fans out to events stream', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
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

    test('onEvent maps provider-lifecycle events to their dedicated kinds',
        () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );
      final received = <CheckoutEvent>[];
      final sub = client.events.listen(received.add);

      client.debugDispatchEvent(
          CheckoutEventDto(kind: CheckoutEventKindDto.paymentProcessing));
      client.debugDispatchEvent(CheckoutEventDto(
        kind: CheckoutEventKindDto.providerError,
        providerReason: 'webview timeout',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(2));
      expect(received[0].kind, CheckoutEventKind.paymentProcessing);
      expect(received[1].kind, CheckoutEventKind.providerError);
      expect(received[1].providerReason, 'webview timeout');

      await sub.cancel();
      await client.dispose();
    });

    test('onError updates lastError and notifies listeners', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
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

    test('onError carries host field for securityTrustFailed', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );
      client.debugDispatchError(OnramperErrorDto(
        kind: OnramperErrorKindDto.securityTrustFailed,
        message: 'trust failed',
        recoverable: false,
        host: 'api.example.com',
      ));
      await Future<void>.delayed(Duration.zero);
      expect(client.lastError?.kind, OnramperErrorKind.securityTrustFailed);
      expect(client.lastError?.host, 'api.example.com');
      await client.dispose();
    });

    test('onSessionExpired invokes the configured handler', () async {
      var handlerCalls = 0;
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
        sessionExpirationHandler: () async {
          handlerCalls++;
          return const SessionCredentials(
              sessionId: 'new', sessionToken: 'newTok');
        },
      );

      await client.debugDispatchSessionExpired();
      expect(handlerCalls, 1);
      expect(fakeHost.lastProvidedCredentials?.sessionId, 'new');
      await client.dispose();
    });

    test('onSessionExpired without handler calls failRefreshedSession',
        () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
        hostApi: fakeHost,
      );

      await client.debugDispatchSessionExpired();
      expect(fakeHost.lastFailReason, isNotNull);
      await client.dispose();
    });

    test('dispose closes streams', () async {
      final fakeHost = FakeOnramperHostApi();
      final client = OnramperClient.forTesting(
        configuration:
            const OnramperConfiguration(apiKey: 'pk_x', clientId: '01H'),
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
  int signOutCallCount = 0;
  ConfigurationDto? lastConfigDto;
  SessionCredentialsDto? lastInitializeCredentials;
  CheckoutRequirementsResultDto? nextRequirementsResult;
  CheckoutButtonStyleDto? lastButtonStyleDto;
  UserPrefillDto? lastPrefillDto;
  SessionCredentialsDto? lastProvidedCredentials;
  String? lastFailReason;
  String? lastCancelledHandle;

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
  Future<CheckoutRequirementsResultDto> getCheckoutRequirements(
    CheckoutIntentRequestDto request,
    UserPrefillDto? prefill,
    CheckoutButtonStyleDto? buttonStyle,
  ) async {
    lastPrefillDto = prefill;
    lastButtonStyleDto = buttonStyle;
    return nextRequirementsResult ??
        CheckoutRequirementsResultDto(
          headlessCheckoutId: 'stub',
          requirements: const [],
          quote: _sampleQuoteDto(),
          buttonHandle: 'stub-handle',
        );
  }

  @override
  Future<void> reset() async {}

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }

  @override
  Future<void> cancelPreparedIntent(String buttonHandle) async {
    lastCancelledHandle = buttonHandle;
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
  }

  @override
  Future<void> provideRefreshedSession(
      SessionCredentialsDto credentials) async {
    lastProvidedCredentials = credentials;
  }

  @override
  Future<void> failRefreshedSession(String reason) async {
    lastFailReason = reason;
  }
}

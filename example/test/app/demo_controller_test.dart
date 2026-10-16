import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter/src/platform/pigeon.g.dart';
import 'package:onramper_flutter_example/app/demo_controller.dart';
import 'package:onramper_flutter_example/config/environments.dart';

import '../support/fake_host.dart';

const fullDefines = {
  'ONRAMPER_DEV_API_KEY': 'pk_test_dev',
  'ONRAMPER_DEV_CLIENT_ID': 'client_dev',
  'ONRAMPER_DEV_DEMO_AUTH_TOKEN': 'token_dev',
  'ONRAMPER_PROD_API_KEY': 'pk_prod',
  'ONRAMPER_PROD_CLIENT_ID': 'client_prod',
  'ONRAMPER_PROD_DEMO_AUTH_TOKEN': 'token_prod',
};

Future<void> settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class Rig {
  final journal = <String>[];
  final hosts = <FakeHost>[];
  final configs = <OnramperConfiguration>[];
  final clients = <OnramperClient>[];
  Completer<void>? mintGate;
  Object? mintError;
  int mints = 0;
  void Function(FakeHost host, int index)? prepareHost;

  DemoController build({Map<String, String> defines = fullDefines}) =>
      DemoController(
        defines: defines,
        onSdkLog: (_) {},
        mintSession: (env) async {
          mints++;
          await mintGate?.future;
          final error = mintError;
          if (error != null) throw error;
          return SessionCredentials(
              sessionId: 's-${env.environment.name}', sessionToken: 't');
        },
        clientFactory: (config, onExpired) {
          final host = FakeHost(journal: journal, tag: 'h${hosts.length}');
          prepareHost?.call(host, hosts.length);
          hosts.add(host);
          configs.add(config);
          final client = OnramperClient.forTesting(
            configuration: config,
            hostApi: host,
            sessionExpirationHandler: onExpired,
          );
          clients.add(client);
          return client;
        },
      );
}

List<String> lines(DemoController c) =>
    c.eventLog.entries.map((e) => e.line).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initializes with dark theme, debug logging and RN log lines', () async {
    final rig = Rig();
    final c = rig.build();
    expect(c.status, InitStatus.initializing);
    await settle();
    expect(c.status, InitStatus.ready);
    expect(c.client, same(rig.clients.single));
    expect(rig.configs.single.theme, OnramperTheme.dark);
    expect(rig.configs.single.logLevel, OnramperLogLevel.debug);
    expect(rig.configs.single.environment, OnramperEnvironment.development);
    expect(rig.configs.single.apiKey, 'pk_test_dev');
    expect(c.settledEnvironment, DemoEnvironment.development);
    expect(lines(c), [
      '[development] minting demo session…',
      'demo session minted',
      '[development] SDK initialized',
    ]);
    c.dispose();
  });

  test('missing .env keys surface as an init error without minting', () async {
    final rig = Rig();
    final c = rig.build(defines: const {});
    await settle();
    expect(c.status, InitStatus.error);
    expect(c.initError, contains('ONRAMPER_DEV_API_KEY'));
    expect(lines(c).last, startsWith('init failed: unknown — .env is missing'));
    expect(rig.mints, 0);
    c.dispose();
  });

  test('retry re-runs after a failure', () async {
    final rig = Rig()..mintError = StateError('boom');
    final c = rig.build();
    await settle();
    expect(c.status, InitStatus.error);
    expect(c.initError, 'unknown — boom');
    rig.mintError = null;
    c.retry();
    expect(c.status, InitStatus.initializing);
    expect(c.initError, isNull);
    await settle();
    expect(c.status, InitStatus.ready);
    c.dispose();
  });

  test('a run superseded while minting never creates a client', () async {
    final rig = Rig()..mintGate = Completer<void>();
    final c = rig.build();
    await settle();
    c.setDarkMode(false);
    rig.mintGate!.complete();
    await settle();
    expect(rig.clients.length, 1);
    expect(rig.configs.single.theme, OnramperTheme.light);
    expect(c.status, InitStatus.ready);
    c.dispose();
  });

  test('a run superseded during initialize is disposed before the next client is configured',
      () async {
    final rig = Rig();
    final gate = Completer<void>();
    rig.prepareHost = (host, index) {
      if (index == 0) host.initializeGate = gate;
    };
    final c = rig.build();
    await settle();
    expect(c.status, InitStatus.initializing);
    expect(c.client, isNull);
    c.setDarkMode(false);
    await settle();
    expect(rig.journal.indexOf('h0.dispose'), greaterThanOrEqualTo(0));
    expect(rig.journal.indexOf('h0.dispose'),
        lessThan(rig.journal.indexOf('h1.configure')));
    gate.complete();
    await settle();
    expect(c.status, InitStatus.ready);
    expect(c.client, same(rig.clients[1]));
    c.dispose();
  });

  test('switching environment signs out, re-initializes, and unlocks when settled',
      () async {
    final rig = Rig();
    final c = rig.build();
    await settle();
    final switching = c.switchEnvironment(DemoEnvironment.production);
    expect(c.isSwitching, isTrue);
    await switching;
    expect(c.client, isNull);
    await settle();
    expect(rig.hosts[0].signOutCalls, 1);
    expect(rig.configs.last.environment, OnramperEnvironment.production);
    expect(rig.configs.last.apiKey, 'pk_prod');
    expect(c.environment, DemoEnvironment.production);
    expect(c.isSwitching, isFalse);
    expect(lines(c), contains('switching environment → production'));
    expect(lines(c), contains('[production] SDK initialized'));
    c.dispose();
  });

  test('a sign-out failure is logged and the switch still happens', () async {
    final rig = Rig();
    rig.prepareHost = (host, index) {
      if (index == 0) {
        host.signOutError = const OnramperError(
          kind: OnramperErrorKind.networkError,
          message: 'offline',
          recoverable: true,
          userMessage: 'No connection',
        );
      }
    };
    final c = rig.build();
    await settle();
    await c.switchEnvironment(DemoEnvironment.production);
    await settle();
    expect(lines(c), contains('sign out failed: networkError — No connection'));
    expect(c.status, InitStatus.ready);
    expect(c.environment, DemoEnvironment.production);
    c.dispose();
  });

  test('switch unlocks when the new environment fails', () async {
    final rig = Rig();
    final devOnly = Map.of(fullDefines)
      ..removeWhere((k, _) => k.startsWith('ONRAMPER_PROD_'));
    final c = rig.build(defines: devOnly);
    await settle();
    await c.switchEnvironment(DemoEnvironment.production);
    await settle();
    expect(c.status, InitStatus.error);
    expect(c.settledEnvironment, DemoEnvironment.production);
    expect(c.isSwitching, isFalse);
    c.dispose();
  });

  test('clearLocalSessions signs out, resets, then re-initializes', () async {
    final rig = Rig();
    final c = rig.build();
    await settle();
    await c.clearLocalSessions();
    await settle();
    expect(rig.journal, containsAllInOrder(
        ['h0.signOut', 'h0.reset', 'h0.dispose', 'h1.configure', 'h1.initialize']));
    expect(c.status, InitStatus.ready);
    c.dispose();
  });

  test('clearLocalSessions superseded by a theme change does not restart again',
      () async {
    final rig = Rig();
    final gate = Completer<void>();
    rig.prepareHost = (host, index) {
      if (index == 0) host.signOutGate = gate;
    };
    final c = rig.build();
    await settle();
    final clearing = c.clearLocalSessions();
    await settle();
    c.setDarkMode(false);
    gate.complete();
    await clearing;
    await settle();
    expect(rig.clients.length, 2);
    expect(rig.hosts[0].resetCalls, 0);
    expect(c.status, InitStatus.ready);
    expect(c.client, same(rig.clients[1]));
    c.dispose();
  });

  test('clearLocalSessions finishing after dispose starts nothing', () async {
    final rig = Rig();
    final gate = Completer<void>();
    rig.prepareHost = (host, index) {
      if (index == 0) host.signOutGate = gate;
    };
    final c = rig.build();
    await settle();
    final clearing = c.clearLocalSessions();
    await settle();
    c.dispose();
    gate.complete();
    await clearing;
    await settle();
    expect(rig.mints, 1);
  });

  test('clearLocalSessions throws without a client', () async {
    final c = Rig().build(defines: const {});
    await settle();
    expect(c.clearLocalSessions(), throwsStateError);
    c.dispose();
  });

  test('state, events and transaction id update the outcome', () async {
    final rig = Rig();
    final c = rig.build();
    await settle();
    final client = c.client!;

    client.debugDispatchStateChanged(
        OnramperStateDto(kind: OnramperStateKindDto.checkoutPreparing));
    client.debugDispatchEvent(
        CheckoutEventDto(kind: CheckoutEventKindDto.checkoutFinalized));
    await settle();
    expect(c.sdkState, OnramperStateKind.checkoutPreparing);
    expect(c.hasFinalizedCheckout, isTrue);
    expect(lines(c), contains('state → checkoutPreparing'));
    expect(lines(c), contains('finalized — transaction null'));

    client.onTransactionIdChanged('tx-1');
    expect(c.transactionId, 'tx-1');

    client.debugDispatchEvent(CheckoutEventDto(
        kind: CheckoutEventKindDto.completed, checkoutId: 'chk-1'));
    await settle();
    expect(c.completedCheckoutId, 'chk-1');
    expect(lines(c), contains('completed chk-1'));

    client.debugDispatchEvent(CheckoutEventDto(
      kind: CheckoutEventKindDto.failed,
      error: OnramperErrorDto(
        kind: OnramperErrorKindDto.paymentFailed,
        message: 'declined',
        userMessage: 'Card declined',
        supportCode: 'X',
        recoverable: true,
      ),
    ));
    await settle();
    expect(c.completedCheckoutId, isNull);
    expect(c.lastFailure, 'paymentFailed — Card declined');
    expect(lines(c), contains('failed paymentFailed — declined'));

    client.debugDispatchEvent(
        CheckoutEventDto(kind: CheckoutEventKindDto.paymentPending));
    await settle();
    expect(c.lastFailure, isNull);
    expect(lines(c).last,
        'Payment processing — track the transaction before starting another payment.');

    client.debugDispatchStateChanged(
        OnramperStateDto(kind: OnramperStateKindDto.ready));
    await settle();
    expect(c.hasFinalizedCheckout, isFalse);

    c.clearOutcome();
    expect(c.completedCheckoutId, isNull);
    expect(c.lastFailure, isNull);
    c.dispose();
  });

  test('session expiry mints a fresh session', () async {
    final rig = Rig();
    final c = rig.build();
    await settle();
    await c.client!.debugDispatchSessionExpired();
    await settle();
    expect(rig.mints, 2);
    expect(lines(c), contains('session expired — minting a new one'));
    c.dispose();
  });
}

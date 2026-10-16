import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter/src/platform/pigeon.g.dart';
import 'package:onramper_flutter_example/logging/log_settings.dart';
import 'package:onramper_flutter_example/main.dart';
import 'package:onramper_flutter_example/config/environments.dart';
import 'package:onramper_flutter_example/screens/buy_crypto_screen.dart';
import 'package:onramper_flutter_example/theme/demo_theme.dart';
import 'package:onramper_flutter_example/widgets/demo_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_host.dart';
import 'support/fake_log_store.dart';

const fullDefines = {
  'ONRAMPER_DEV_API_KEY': 'pk_test_dev',
  'ONRAMPER_DEV_CLIENT_ID': 'client_dev',
  'ONRAMPER_DEV_DEMO_AUTH_TOKEN': 'token_dev',
  'ONRAMPER_PROD_API_KEY': 'pk_prod',
  'ONRAMPER_PROD_CLIENT_ID': 'client_prod',
  'ONRAMPER_PROD_DEMO_AUTH_TOKEN': 'token_prod',
};

void main() {
  late LogSettings settings;
  late FakeLogFileStore store;
  late List<FakeHost> hosts;
  late List<OnramperClient> clients;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await LogSettings.load();
    store = FakeLogFileStore();
    hosts = [];
    clients = [];
  });

  Future<void> pumpApp(WidgetTester tester,
      {Map<String, String> defines = fullDefines}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ExampleApp(
      logSettings: settings,
      logStore: store,
      defines: defines,
      shareFile: (_, __) async {},
      mintSession: (_) async =>
          const SessionCredentials(sessionId: 's', sessionToken: 't'),
      clientFactory: (config, onExpired) {
        final host = FakeHost();
        hosts.add(host);
        final c = OnramperClient.forTesting(
            configuration: config,
            hostApi: host,
            sessionExpirationHandler: onExpired);
        clients.add(c);
        return c;
      },
    ));
    await tester.pumpAndSettle();
  }

  SystemUiOverlayStyle statusBarStyle(WidgetTester tester) => tester
      .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first)
      .value;

  Finder amountField() => find.descendant(
      of: find.widgetWithText(DemoCard, 'Amount'),
      matching: find.byType(TextField));

  for (final field in ['amount', 'wallet']) {
    testWidgets('$field drafts block checkout until the new quote arrives',
        (tester) async {
      await pumpApp(tester);
      final input = field == 'amount'
          ? amountField()
          : find.descendant(
              of: find.widgetWithText(DemoCard, 'Wallet address (solana)'),
              matching: find.byType(TextField));
      final button = find.byType(OnramperCheckoutButton);
      final originalElement = tester.element(button);
      final gate = Completer<void>();
      hosts.single.requirementsGates.add(gate);

      await tester.enterText(input, field == 'amount' ? '250' : 'new-wallet');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
      expect(hosts.single.requirementsCalls, 1);
      expect(tester.element(button), same(originalElement));
      final blocker =
          find.ancestor(of: button, matching: find.byType(AbsorbPointer));
      expect(
          tester
              .widgetList<AbsorbPointer>(blocker)
              .any((widget) => widget.absorbing),
          isTrue);

      await tester.pump(const Duration(milliseconds: 150));
      expect(hosts.single.requirementsCalls, 2);
      expect(button, findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<OnramperCheckoutButton>(button)
              .requirements
              .buttonHandle,
          'button-2');
      expect(
          tester
              .widgetList<AbsorbPointer>(find.ancestor(
                  of: button, matching: find.byType(AbsorbPointer)))
              .any((widget) => widget.absorbing),
          isFalse);
    });
  }

  testWidgets('reverting a draft re-enables the same mounted checkout',
      (tester) async {
    await pumpApp(tester);
    final button = find.byType(OnramperCheckoutButton);
    final originalElement = tester.element(button);
    await tester.enterText(amountField(), '250');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(amountField(), '100');
    await tester.pumpAndSettle();
    expect(hosts.single.requirementsCalls, 1);
    expect(tester.element(button), same(originalElement));
    expect(
        tester
            .widgetList<AbsorbPointer>(
                find.ancestor(of: button, matching: find.byType(AbsorbPointer)))
            .any((widget) => widget.absorbing),
        isFalse);
  });

  for (final action in ['Reset', 'Log out']) {
    for (final environmentChange in [false, true]) {
      for (final fails in [false, true]) {
        testWidgets(
            'stale $action ${fails ? 'failure' : 'success'} after ${environmentChange ? 'environment' : 'theme'} change is ignored',
            (tester) async {
          await pumpApp(tester);
          final old = hosts.single;
          final gate = Completer<void>();
          if (action == 'Reset') {
            old.resetGate = gate;
            if (fails) old.resetError = StateError('old action failed');
          } else {
            old.signOutGate = gate;
            if (fails) old.signOutError = StateError('old action failed');
          }
          await tester.scrollUntilVisible(find.text(action), 300,
              scrollable: find.byType(Scrollable).first);
          await tester.tap(find.text(action));
          await tester.pump();
          expect(action == 'Reset' ? old.resetCalls : old.signOutCalls, 1);
          final demo =
              tester.widget<BuyCryptoScreen>(find.byType(BuyCryptoScreen)).demo;
          if (environmentChange) {
            // The switch's own sign-out is independent of the pending action.
            old.signOutGate = null;
            old.signOutError = null;
            await demo.switchEnvironment(DemoEnvironment.production);
          } else {
            demo.setDarkMode(false);
          }
          await tester.pumpAndSettle();
          expect(clients.length, 2);
          clients.last.debugDispatchEvent(CheckoutEventDto(
              kind: CheckoutEventKindDto.completed,
              checkoutId: 'new-checkout'));
          await tester.pumpAndSettle();
          expect(demo.completedCheckoutId, 'new-checkout');
          final quotes = hosts.last.requirementsCalls;
          if (action == 'Log out' && fails) {
            old.signOutError = StateError('old action failed');
          }
          gate.complete();
          await tester.pumpAndSettle();
          expect(demo.completedCheckoutId, 'new-checkout');
          expect(hosts.last.requirementsCalls, quotes);
          expect(find.textContaining('old action failed'), findsNothing);
          expect(
              demo.eventLog.entries
                  .any((entry) => entry.line.contains('old action failed')),
              isFalse);
        });
      }
    }
  }

  testWidgets('renders the Buy Crypto screen and quotes on launch',
      (tester) async {
    await pumpApp(tester);
    expect(find.text('Buy Crypto'), findsOneWidget);
    expect(find.text('Development'), findsOneWidget);
    expect(find.text('Select currency'), findsOneWidget);
    expect(find.text('Wallet address (solana)'), findsOneWidget);
    expect(find.text('Quote'), findsOneWidget);
    expect(find.byType(OnramperCheckoutButton), findsOneWidget);
    expect(hosts.single.requirementsCalls, 1);
    expect(hosts.single.lastConfig?.theme, ThemeDto.dark);
    expect(hosts.single.lastConfig?.logLevel, LogLevelDto.debug);
    expect(statusBarStyle(tester), SystemUiOverlayStyle.light);
  });

  testWidgets('editing the amount re-quotes after the typing debounce',
      (tester) async {
    await pumpApp(tester);
    await tester.enterText(amountField(), '250');
    await tester.pump(const Duration(milliseconds: 300));
    expect(hosts.single.requirementsCalls, 1);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(hosts.single.requirementsCalls, 2);
    expect(hosts.single.lastRequest?.transactionData.amount, 250);
  });

  testWidgets('an invalid amount shows the RN hint and no quote',
      (tester) async {
    await pumpApp(tester);
    await tester.enterText(amountField(), '0');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount greater than 0'), findsOneWidget);
    expect(find.text('Quote'), findsNothing);
    expect(find.text('Buy'), findsOneWidget);
  });

  testWidgets('init error shows the error box with Retry', (tester) async {
    await pumpApp(tester, defines: const {});
    expect(find.text('SDK initialization failed'), findsOneWidget);
    expect(find.textContaining('ONRAMPER_DEV_API_KEY'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('quote errors show "Quote failed"', (tester) async {
    await pumpApp(tester);
    hosts.single.requirementsError = const OnramperError(
      kind: OnramperErrorKind.quoteUnavailable,
      message: 'raw',
      recoverable: true,
      userMessage: 'No quotes',
      supportCode: 'IOS-QUOTE-123',
    );
    await tester.tap(find.text('BTC'));
    await tester.pumpAndSettle();
    expect(find.text('Quote failed'), findsOneWidget);
    expect(find.text('quoteUnavailable — No quotes\nError code: IOS-QUOTE-123'),
        findsOneWidget);
  });

  testWidgets(
      'Settings opens with every RN section, and dark mode re-initializes',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('⚙︎'));
    await tester.pumpAndSettle();
    for (final text in [
      'Settings',
      'Environment',
      'Clear local sessions',
      'Appearance',
      'Diagnostic logs',
      'About',
      'Library',
      'OnramperSDK',
      'Bundle ID',
      'Team ID'
    ]) {
      await tester.scrollUntilVisible(find.text(text).last, 100,
          scrollable: find.byType(Scrollable).last);
      expect(find.text(text), findsWidgets, reason: text);
    }
    await tester.scrollUntilVisible(find.text('Dark mode'), -100,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find
        .descendant(
            of: find.ancestor(
                of: find.text('Dark mode'), matching: find.byType(Row)),
            matching: find.byType(Switch))
        .first);
    await tester.pumpAndSettle();
    expect(hosts.length, 2);
    expect(hosts.last.lastConfig?.theme, ThemeDto.light);
    final theme = tester.widget<DemoTheme>(find.byType(DemoTheme).first);
    expect(theme.palette.isDark, isFalse);
    expect(statusBarStyle(tester), SystemUiOverlayStyle.dark);
  });

  testWidgets('SDK events do not rebuild the MaterialApp', (tester) async {
    await pumpApp(tester);
    final before = tester.widget<MaterialApp>(find.byType(MaterialApp));
    clients.single.debugDispatchStateChanged(
        OnramperStateDto(kind: OnramperStateKindDto.checkoutPreparing));
    await tester.pumpAndSettle();
    expect(find.text('SDK: checkoutPreparing'), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)), same(before));
  });

  testWidgets('a failed checkout keeps its quote in recovery until re-quoted',
      (tester) async {
    await pumpApp(tester);
    expect(find.byType(OnramperCheckoutButton), findsOneWidget);
    clients.single.debugDispatchStateChanged(
        OnramperStateDto(kind: OnramperStateKindDto.failed));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t start checkout'), findsOneWidget);

    // Its native button was unmounted and its handle consumed; showing it
    // again would render nothing.
    clients.single.debugDispatchStateChanged(
        OnramperStateDto(kind: OnramperStateKindDto.ready));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t start checkout'), findsOneWidget);
    expect(find.byType(OnramperCheckoutButton), findsNothing);

    await tester.ensureVisible(find.text('Get a new quote'));
    await tester.tap(find.text('Get a new quote'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t start checkout'), findsNothing);
    final button = tester
        .widget<OnramperCheckoutButton>(find.byType(OnramperCheckoutButton));
    expect(button.requirements.buttonHandle, 'button-2');
  });

  testWidgets('Save SDK logs off stops file writes', (tester) async {
    await pumpApp(tester);
    final record = OnramperLogRecord(
      timestamp: DateTime.utc(2026),
      level: OnramperLogLevel.info,
      category: 'c',
      event: 'e',
      context: const {},
      message: 'm',
    );
    clients.single.configuration.logHandler!(record);
    expect(store.appended.length, 1);
    await settings.setEnabled(false);
    clients.single.configuration.logHandler!(record);
    expect(store.appended.length, 1);
  });
}

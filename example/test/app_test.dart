import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter/src/platform/pigeon.g.dart';
import 'package:onramper_flutter_example/logging/log_settings.dart';
import 'package:onramper_flutter_example/main.dart';
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

  Future<void> pumpApp(WidgetTester tester, {Map<String, String> defines = fullDefines}) async {
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
            configuration: config, hostApi: host, sessionExpirationHandler: onExpired);
        clients.add(c);
        return c;
      },
    ));
    await tester.pumpAndSettle();
  }

  Finder amountField() => find.descendant(
      of: find.widgetWithText(DemoCard, 'Amount'), matching: find.byType(TextField));

  testWidgets('renders the Buy Crypto screen and quotes on launch', (tester) async {
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
  });

  testWidgets('editing the amount re-quotes after the typing debounce', (tester) async {
    await pumpApp(tester);
    await tester.enterText(amountField(), '250');
    await tester.pump(const Duration(milliseconds: 300));
    expect(hosts.single.requirementsCalls, 1);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(hosts.single.requirementsCalls, 2);
    expect(hosts.single.lastRequest?.transactionData.amount, 250);
  });

  testWidgets('an invalid amount shows the RN hint and no quote', (tester) async {
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
    );
    await tester.tap(find.text('BTC'));
    await tester.pumpAndSettle();
    expect(find.text('Quote failed'), findsOneWidget);
    expect(find.text('quoteUnavailable — No quotes'), findsOneWidget);
  });

  testWidgets('Settings opens with every RN section, and dark mode re-initializes',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('⚙︎'));
    await tester.pumpAndSettle();
    for (final text in ['Settings', 'Environment', 'Clear local sessions', 'Appearance',
        'Diagnostic logs', 'About', 'Library', 'OnramperSDK', 'Bundle ID', 'Team ID']) {
      await tester.scrollUntilVisible(find.text(text).last, 100,
          scrollable: find.byType(Scrollable).last);
      expect(find.text(text), findsWidgets, reason: text);
    }
    await tester.scrollUntilVisible(find.text('Dark mode'), -100,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.descendant(
        of: find.ancestor(of: find.text('Dark mode'), matching: find.byType(Row)),
        matching: find.byType(Switch)).first);
    await tester.pumpAndSettle();
    expect(hosts.length, 2);
    expect(hosts.last.lastConfig?.theme, ThemeDto.light);
    final theme = tester.widget<DemoTheme>(find.byType(DemoTheme).first);
    expect(theme.palette.isDark, isFalse);
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

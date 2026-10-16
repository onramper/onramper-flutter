import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter_example/checkout/prefill.dart';
import 'package:onramper_flutter_example/logging/event_log.dart';
import 'package:onramper_flutter_example/logging/log_settings.dart';
import 'package:onramper_flutter_example/widgets/diagnostics_card.dart';
import 'package:onramper_flutter_example/widgets/event_log_card.dart';
import 'package:onramper_flutter_example/widgets/prefill_card.dart';
import 'package:onramper_flutter_example/widgets/quote_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_log_store.dart';
import '../support/harness.dart';

void main() {
  testWidgets('QuoteCard rows match RN', (tester) async {
    await tester.pumpWidget(harness(const QuoteCard(
      quote: QuoteResponse(
        quoteId: 'q',
        ramp: 'moonpay',
        rate: 50000,
        networkFee: 1,
        transactionFee: 2.5,
        payout: 0.002,
        paymentMethod: 'applepay',
      ),
      amount: 100,
      fiat: 'usd',
      cryptoSymbol: 'BTC',
    )));
    expect(find.text('Quote'), findsOneWidget);
    expect(find.text('100.00 USD'), findsOneWidget);
    expect(find.text('0.002000 BTC'), findsOneWidget);
    expect(find.text('1 BTC ≈ 50000.00 USD'), findsOneWidget);
    expect(find.text('2.50 USD'), findsOneWidget);
    expect(find.text('MOONPAY'), findsOneWidget);
  });

  testWidgets('PrefillCard collapses, shows the summary, and edits', (tester) async {
    var value = const PrefillInput();
    await tester.pumpWidget(harness(StatefulBuilder(
      builder: (context, setState) => PrefillCard(
        value: value,
        onChanged: (v) => setState(() => value = v),
      ),
    )));
    expect(find.text('Sends: nothing ▸'), findsOneWidget);
    expect(find.text('Send prefill'), findsNothing);
    await tester.tap(find.text('Prefill'));
    await tester.pump();
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(value.enabled, isTrue);
    expect(find.text('Sends: firstName, lastName ▾'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(2), '+371');
    expect(value.phoneNumber, '+371');
  });

  testWidgets('EventLogCard expands, colours by level and clears', (tester) async {
    final log = EventLog(clock: () => DateTime.utc(2026, 1, 1, 8, 0, 1))
      ..add(EventLevel.info, 'hello')
      ..add(EventLevel.error, 'boom');
    await tester.pumpWidget(harness(EventLogCard(log: log)));
    expect(find.text('SDK events (2) ▸'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
    await tester.tap(find.text('SDK events (2) ▸'));
    await tester.pump();
    expect(find.text('08:00:01 hello'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('(empty)'), findsOneWidget);
  });

  group('DiagnosticsCard', () {
    late LogSettings settings;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = await LogSettings.load();
    });

    testWidgets('lists files, toggles saving, shares and deletes', (tester) async {
      final store = FakeLogFileStore()
        ..files = [fakeLogFile('2026-10-16', 2048), fakeLogFile('2026-10-15', 100)];
      File? shared;
      await tester.pumpWidget(harness(DiagnosticsCard(
        settings: settings,
        store: store,
        share: (file, origin) async => shared = file,
      )));
      await tester.pump();
      expect(find.text('2 files · 3 KB'), findsOneWidget);
      expect(find.text('onramper-sdk-2026-10-16.log'), findsOneWidget);
      expect(find.text('2 KB · UTC'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(settings.enabled, isFalse);

      await tester.tap(find.text('Share').first);
      await tester.pump();
      expect(shared?.path, endsWith('onramper-sdk-2026-10-16.log'));

      await tester.tap(find.text('Delete all logs'));
      await tester.pumpAndSettle();
      expect(find.text('Delete all logs?'), findsOneWidget);
      await tester.tap(find.text('Delete all'));
      await tester.pumpAndSettle();
      expect(store.deleted, isTrue);
      expect(find.text('No log files yet.'), findsOneWidget);
    });

    testWidgets('opens a preview sheet', (tester) async {
      final store = FakeLogFileStore()..files = [fakeLogFile('2026-10-16', 10)];
      await tester.pumpWidget(harness(DiagnosticsCard(
        settings: settings,
        store: store,
        share: (_, __) async {},
      )));
      await tester.pump();
      await tester.tap(find.text('onramper-sdk-2026-10-16.log'));
      await tester.pumpAndSettle();
      expect(find.text('Log preview'), findsOneWidget);
      expect(find.text('line one\nline two'), findsOneWidget);
    });
  });

  test('fileSize matches RN', () {
    expect(fileSize(100), '1 KB');
    expect(fileSize(2048), '2 KB');
    expect(fileSize(3 * 1024 * 1024 + 1), '3.0 MB');
  });

}

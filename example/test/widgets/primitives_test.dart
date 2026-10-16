import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter_example/widgets/demo_card.dart';
import 'package:onramper_flutter_example/widgets/demo_dropdown.dart';
import 'package:onramper_flutter_example/widgets/option_sheet.dart';
import 'package:onramper_flutter_example/widgets/segmented.dart';
import 'package:onramper_flutter_example/widgets/sheet_header.dart';
import 'package:onramper_flutter_example/widgets/status_box.dart';
import 'package:onramper_flutter_example/widgets/switch_row.dart';
import 'package:onramper_flutter_example/widgets/tile.dart';

import '../support/harness.dart';

void main() {
  testWidgets('DemoCard shows title, children and footer', (tester) async {
    await tester.pumpWidget(harness(const DemoCard(
      title: 'Amount',
      footer: 'Footnote',
      children: [Text('body')],
    )));
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
    expect(find.text('Footnote'), findsOneWidget);
  });

  testWidgets('SheetHeader keeps the close mark on the leading edge',
      (tester) async {
    // Sheets lay the header out in a Column that doesn't stretch children.
    await tester.pumpWidget(harness(Column(children: [
      SheetHeader(title: 'Settings', onClose: () {}),
    ])));
    expect(tester.getTopLeft(find.byIcon(Icons.close)).dx, lessThan(40));
    expect(tester.getCenter(find.text('Settings')).dx,
        moreOrLessEquals(400, epsilon: 1));
  });

  testWidgets('Segmented reports taps and ignores them when disabled',
      (tester) async {
    String? picked;
    Widget build(bool disabled) => harness(Segmented<String>(
          options: const [SegmentOption('a', 'A'), SegmentOption('b', 'B')],
          value: 'a',
          disabled: disabled,
          onChanged: (v) => picked = v,
        ));
    await tester.pumpWidget(build(false));
    await tester.tap(find.text('B'));
    expect(picked, 'b');
    picked = null;
    await tester.pumpWidget(build(true));
    await tester.tap(find.text('B'));
    expect(picked, isNull);
  });

  testWidgets('SwitchRow toggles', (tester) async {
    bool? value;
    await tester.pumpWidget(harness(SwitchRow(
      label: 'Dark mode',
      value: false,
      onChanged: (v) => value = v,
    )));
    await tester.tap(find.byType(Switch));
    expect(value, isTrue);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final disabled in [false, true]) {
      testWidgets(
          'SwitchRow labels its ${platform.name} ${disabled ? 'disabled' : 'enabled'} toggle',
          (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        final semantics = tester.ensureSemantics();
        try {
          bool? changed;
          await tester.pumpWidget(harness(SwitchRow(
            label: 'Dark mode',
            value: !disabled,
            disabled: disabled,
            onChanged: (value) => changed = value,
          )));
          final node = tester.getSemantics(find.byType(Switch));
          expect(
              node,
              // isSemantics is unavailable on the supported Flutter 3.22.
              // ignore: deprecated_member_use
              containsSemantics(
                label: 'Dark mode',
                hasToggledState: true,
                isToggled: !disabled,
                isEnabled: !disabled,
                hasTapAction: !disabled,
              ));
          if (!disabled) {
            await tester.tap(find.byType(Switch));
            await tester.pump();
            expect(changed, isFalse);
          }
        } finally {
          semantics.dispose();
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }

  testWidgets('Tile taps unless disabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(TileRow(children: [
      Tile(
          label: 'BTC',
          sublabel: 'Bitcoin',
          selected: true,
          onTap: () => taps++),
      Tile(label: 'ETH', selected: false, disabled: true, onTap: () => taps++),
    ])));
    await tester.tap(find.text('BTC'));
    await tester.tap(find.text('ETH'));
    expect(taps, 1);
    expect(find.text('Bitcoin'), findsOneWidget);
  });

  testWidgets('StatusBox shows its action only with a handler', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(Column(children: [
      StatusBox(
        tone: StatusTone.error,
        title: 'Quote failed',
        body: 'x — y',
        actionLabel: 'Retry',
        onAction: () => taps++,
      ),
      const StatusBox(
          tone: StatusTone.info, title: 'Info', actionLabel: 'Nope'),
    ])));
    await tester.tap(find.text('Retry'));
    expect(taps, 1);
    expect(find.text('Nope'), findsNothing);
  });

  testWidgets('DemoDropdown opens inline, selects and closes', (tester) async {
    String value = 'any';
    await tester.pumpWidget(harness(StatefulBuilder(
      builder: (context, setState) => DemoDropdown<String>(
        label: 'Onramp',
        options: const [
          SegmentOption('any', 'Any'),
          SegmentOption('moonpay', 'MoonPay'),
        ],
        value: value,
        onChanged: (v) => setState(() => value = v),
      ),
    )));
    expect(find.text('MoonPay'), findsNothing);
    await tester.tap(find.text('Any'));
    await tester.pump();
    await tester.tap(find.text('MoonPay'));
    await tester.pump();
    expect(value, 'moonpay');
    expect(find.text('Any'), findsNothing);
  });

  testWidgets('showOptionSheet selects and closes', (tester) async {
    String? picked;
    await tester.pumpWidget(harness(Builder(
      builder: (context) => TextButton(
        onPressed: () => showOptionSheet(
          context,
          title: 'US state',
          options: const [
            SegmentOption('AL', 'Alabama (AL)'),
            SegmentOption('CA', 'California (CA)'),
          ],
          selected: 'CA',
          onSelect: (v) => picked = v,
        ),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('US state'), findsOneWidget);
    expect(find.text('✓'), findsOneWidget);
    await tester.tap(find.text('Alabama (AL)'));
    await tester.pumpAndSettle();
    expect(picked, 'AL');
    expect(find.text('US state'), findsNothing);
  });
}

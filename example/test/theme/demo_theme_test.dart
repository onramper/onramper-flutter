import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter_example/theme/demo_theme.dart';

void main() {
  test('palettes match RN theme.ts', () {
    const d = DemoPalette.dark;
    expect(d.headerBg, const Color(0xFF000000));
    expect(d.contentBg, const Color(0xFF121217));
    expect(d.cardBg, const Color(0xFF1F1F24));
    expect(d.accent, const Color(0xFFB5F798));
    expect(d.textSecondary, const Color(0xFF8E8E93));
    expect(d.inputBg, const Color(0x1A8E8E93));
    expect(d.border, const Color(0x4D8E8E93));
    expect(d.danger, const Color(0xFFFF453A));
    const l = DemoPalette.light;
    expect(l.headerBg, const Color(0xFFF5F5FA));
    expect(l.contentBg, const Color(0xFFF2F2F7));
    expect(l.accent, const Color(0xFFF831FD));
    expect(l.text, const Color(0xFF000000));
    expect(l.textSecondary, const Color(0xFF6C6C70));
    expect(l.success, const Color(0xFF34C759));
    expect(l.warning, const Color(0xFFFF9500));
    expect(DemoPalette.of(true), same(DemoPalette.dark));
    expect(DemoPalette.of(false).isDark, isFalse);
  });

  test('checkout button uses accent, onAccent and button radius', () {
    final style = checkoutButtonStyle(DemoPalette.dark);
    expect(style.backgroundColor, DemoPalette.dark.accent);
    expect(style.foregroundColor, DemoPalette.dark.onAccent);
    expect(style.borderRadius, DemoRadius.button);
  });

  testWidgets('DemoTheme.of returns the nearest palette', (tester) async {
    late DemoPalette seen;
    await tester.pumpWidget(DemoTheme(
      palette: DemoPalette.light,
      child: Builder(builder: (context) {
        seen = DemoTheme.of(context);
        return const SizedBox();
      }),
    ));
    expect(seen, same(DemoPalette.light));
  });
}

import 'package:flutter/material.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

/// Colour tokens ported 1:1 from the RN example's `theme.ts`.
@immutable
class DemoPalette {
  const DemoPalette._({
    required this.brightness,
    required this.headerBg,
    required this.contentBg,
    required this.cardBg,
    required this.accent,
    required this.onAccent,
    required this.text,
    required this.textSecondary,
    required this.inputBg,
    required this.border,
    required this.danger,
    required this.success,
    required this.warning,
  });

  static const dark = DemoPalette._(
    brightness: Brightness.dark,
    headerBg: Color(0xFF000000),
    contentBg: Color(0xFF121217),
    cardBg: Color(0xFF1F1F24),
    accent: Color(0xFFB5F798),
    onAccent: Color(0xFF000000),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8E8E93),
    inputBg: Color(0x1A8E8E93),
    border: Color(0x4D8E8E93),
    danger: Color(0xFFFF453A),
    success: Color(0xFF30D158),
    warning: Color(0xFFFF9F0A),
  );

  static const light = DemoPalette._(
    brightness: Brightness.light,
    headerBg: Color(0xFFF5F5FA),
    contentBg: Color(0xFFF2F2F7),
    cardBg: Color(0xFFFFFFFF),
    accent: Color(0xFFF831FD),
    onAccent: Color(0xFF000000),
    text: Color(0xFF000000),
    textSecondary: Color(0xFF6C6C70),
    inputBg: Color(0x1A8E8E93),
    border: Color(0x4D8E8E93),
    danger: Color(0xFFFF3B30),
    success: Color(0xFF34C759),
    warning: Color(0xFFFF9500),
  );

  static DemoPalette of(bool isDark) => isDark ? dark : light;

  final Brightness brightness;
  final Color headerBg;
  final Color contentBg;
  final Color cardBg;
  final Color accent;
  final Color onAccent;
  final Color text;
  final Color textSecondary;
  final Color inputBg;
  final Color border;
  final Color danger;
  final Color success;
  final Color warning;

  bool get isDark => brightness == Brightness.dark;
}

/// `RADIUS` from RN `theme.ts`.
abstract final class DemoRadius {
  static const card = 16.0;
  static const tile = 12.0;
  static const input = 10.0;
  static const button = 14.0;
}

const kMonoFont = 'Menlo';

extension DemoColor on Color {
  /// This colour at [opacity] (RN `withAlpha`). Works on Flutter 3.22, which
  /// has no `Color.withValues`.
  Color faded(double opacity) => withAlpha((opacity * 255).round());
}

/// Makes the active [DemoPalette] available to every route.
class DemoTheme extends InheritedWidget {
  const DemoTheme({super.key, required this.palette, required super.child});

  final DemoPalette palette;

  static DemoPalette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DemoTheme>()!.palette;

  @override
  bool updateShouldNotify(DemoTheme oldWidget) => oldWidget.palette != palette;
}

/// Keeps Material-drawn pieces (dialogs, selection) in step with the palette.
/// The status bar follows the palette via BuyCryptoScreen's AnnotatedRegion.
ThemeData buildMaterialTheme(DemoPalette p) => ThemeData(
      brightness: p.brightness,
      scaffoldBackgroundColor: p.contentBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: p.brightness,
      ).copyWith(
        primary: p.accent,
        onPrimary: p.onAccent,
        surface: p.cardBg,
        error: p.danger,
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: p.accent),
    );

/// Same style RN passes to `getCheckoutRequirements`.
CheckoutButtonStyle checkoutButtonStyle(DemoPalette p) => CheckoutButtonStyle(
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      borderRadius: DemoRadius.button,
    );

import 'package:flutter/material.dart';

import '../platform/pigeon.g.dart';

/// Visual customization for the native checkout button.
///
/// The `backgroundColor`, `foregroundColor`, and `borderRadius` fields are
/// forwarded to the native checkout button (via
/// [OnramperClient.getCheckoutRequirements]). The ToS sentence below Buy is
/// rendered natively and follows the configured [OnramperTheme].
///
/// The native button's label text ("Buy") is fixed by the SDK and not
/// currently overridable from Dart.
class CheckoutButtonStyle {
  const CheckoutButtonStyle({
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = 12,
    @Deprecated(_tosDeprecation) this.tosStyle,
    @Deprecated(_tosDeprecation) this.tosLinkStyle,
  });

  static const _tosDeprecation = 'The native button renders the ToS text. '
      'Has no effect; will be removed in a future major version.';

  /// Fill color of the native checkout button. Null → SDK default
  /// (system blue).
  final Color? backgroundColor;

  /// Text color of the native checkout button. Null → SDK default (white).
  final Color? foregroundColor;

  /// Corner radius in logical points. Applied to the native button.
  final double borderRadius;

  /// No effect. The native button renders the ToS text.
  @Deprecated(_tosDeprecation)
  final TextStyle? tosStyle;

  /// No effect. The native button renders the ToS links.
  @Deprecated(_tosDeprecation)
  final TextStyle? tosLinkStyle;

  /// Serializes the native-visible fields into a pigeon DTO so
  /// [OnramperClient.getCheckoutRequirements] can pass them across the
  /// bridge. Returns null when nothing overrides the SDK defaults.
  CheckoutButtonStyleDto? toNativeDto() {
    final bg = backgroundColor;
    final fg = foregroundColor;
    if (bg == null && fg == null && borderRadius == 12) return null;
    return CheckoutButtonStyleDto(
      backgroundColor: bg == null ? null : _colorToHex(bg),
      foregroundColor: fg == null ? null : _colorToHex(fg),
      borderRadius: borderRadius,
    );
  }
}

/// Converts a Flutter [Color] to `#RRGGBBAA` — matching the format the RN
/// SDK uses on the bridge, so both wrappers stay symmetric.
String _colorToHex(Color color) {
  // ignore: deprecated_member_use — Color.value is stable on Flutter 3.22.
  final v = color.value;
  final a = (v >> 24) & 0xff;
  final r = (v >> 16) & 0xff;
  final g = (v >> 8) & 0xff;
  final b = v & 0xff;
  String two(int i) => i.toRadixString(16).padLeft(2, '0');
  return '#${two(r)}${two(g)}${two(b)}${two(a)}';
}

import 'package:flutter/material.dart';

/// Visual customization for [OnramperCheckoutButton].
///
/// All fields have sensible defaults so consumers can pass
/// `const CheckoutButtonStyle()` and tweak only what they need.
class CheckoutButtonStyle {
  const CheckoutButtonStyle({
    this.backgroundColor = Colors.black,
    this.foregroundColor = Colors.white,
    this.borderRadius = 12,
    this.labelStyle,
    this.tosStyle,
    this.tosLinkStyle,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final double borderRadius;
  final TextStyle? labelStyle;
  final TextStyle? tosStyle;
  final TextStyle? tosLinkStyle;
}

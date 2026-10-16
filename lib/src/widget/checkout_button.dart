import 'package:flutter/widgets.dart';

import '../models/requirements.dart';
import 'checkout_button_style.dart';
import 'native_checkout_button.dart';

/// Consumer-facing checkout button: embeds the native button prepared by
/// [OnramperClient.getCheckoutRequirements] via [OnramperNativeCheckoutButton].
///
/// The native button handles the full checkout flow (OIDC login, finalize,
/// payment webview) without a separate `presentCheckout()` call, and renders
/// the Terms of Service consent sentence (with its links) below Buy itself.
class OnramperCheckoutButton extends StatelessWidget {
  const OnramperCheckoutButton({
    super.key,
    required this.requirements,
    this.style = const CheckoutButtonStyle(),
    @Deprecated('The native button renders and opens the ToS links itself. '
        'Has no effect; will be removed in a future major version.')
    this.onLinkTap,
  });

  final CheckoutRequirementsResult requirements;

  /// Kept for source compatibility. The button's colors and radius are applied
  /// natively when passed to [OnramperClient.getCheckoutRequirements].
  final CheckoutButtonStyle style;

  /// No effect. The native button opens the ToS links itself.
  @Deprecated('The native button renders and opens the ToS links itself. '
      'Has no effect; will be removed in a future major version.')
  final Future<bool> Function(Uri)? onLinkTap;

  @override
  Widget build(BuildContext context) =>
      OnramperNativeCheckoutButton(buttonHandle: requirements.buttonHandle);
}

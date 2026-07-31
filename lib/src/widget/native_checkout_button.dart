import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Embeds the native iOS `OnramperCheckoutButton` (SwiftUI) directly in the
/// Flutter widget tree via a platform view.
///
/// Use the [buttonHandle] returned by [OnramperClient.getCheckoutRequirements].
/// The native button handles the full checkout flow — OIDC login, finalize,
/// and payment webview — without a separate `presentCheckout()` call.
///
/// Only supported on iOS. Renders an empty [SizedBox] on other platforms.
class OnramperNativeCheckoutButton extends StatelessWidget {
  const OnramperNativeCheckoutButton({
    super.key,
    required this.buttonHandle,
    this.height = 56.0,
  });

  final String buttonHandle;

  /// Height of the native button. Defaults to 56 logical pixels.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: height,
      child: UiKitView(
        viewType: 'OnramperCheckoutButton',
        creationParams: {'handle': buttonHandle},
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}

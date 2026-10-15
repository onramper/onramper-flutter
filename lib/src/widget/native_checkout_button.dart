import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../platform/pigeon.g.dart';
import 'checkout_button_height.dart';

/// Embeds the native iOS `OnramperCheckoutButton` (SwiftUI) directly in the
/// Flutter widget tree via a platform view.
///
/// Use the [buttonHandle] returned by [OnramperClient.getCheckoutRequirements].
/// The native button handles the full checkout flow — OIDC login, finalize,
/// and payment webview — without a separate `presentCheckout()` call.
///
/// Sizes itself to the native content (Buy button, Terms of Service text,
/// provider payment disclosures). Shows nothing when [buttonHandle] has
/// expired or been superseded by a newer `getCheckoutRequirements` call.
///
/// Only supported on iOS. Renders an empty [SizedBox] on other platforms.
class OnramperNativeCheckoutButton extends StatefulWidget {
  const OnramperNativeCheckoutButton({
    super.key,
    required this.buttonHandle,
    @Deprecated('The button sizes itself. Kept as a minimum height; will be '
        'removed in a future major release.')
    this.height,
  });

  final String buttonHandle;

  /// Minimum height. Deprecated; the button sizes itself.
  @Deprecated('The button sizes itself.')
  final double? height;

  @override
  State<OnramperNativeCheckoutButton> createState() =>
      _OnramperNativeCheckoutButtonState();
}

class _OnramperNativeCheckoutButtonState
    extends State<OnramperNativeCheckoutButton> {
  late CheckoutButtonHeightController _height = _newController();
  int? _viewId;

  CheckoutButtonHeightController _newController() =>
      // ignore: deprecated_member_use_from_same_package
      CheckoutButtonHeightController(minHeight: widget.height ?? 0);

  @override
  void didUpdateWidget(OnramperNativeCheckoutButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buttonHandle != widget.buttonHandle) {
      _detach();
      _height.dispose();
      _height = _newController();
    }
  }

  void _onPlatformViewCreated(int id) {
    _viewId = id;
    CheckoutButtonFlutterApi.setUp(_height, messageChannelSuffix: '$id');
  }

  void _detach() {
    final id = _viewId;
    if (id != null) {
      CheckoutButtonFlutterApi.setUp(null, messageChannelSuffix: '$id');
    }
    _viewId = null;
  }

  @override
  void dispose() {
    _detach();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: _height,
      builder: (context, child) =>
          SizedBox(height: _height.height, child: child),
      child: UiKitView(
        // A new handle needs a new native view; the key forces recreation.
        key: ValueKey(widget.buttonHandle),
        viewType: 'OnramperCheckoutButton',
        creationParams: {'handle': widget.buttonHandle},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      ),
    );
  }
}

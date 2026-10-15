import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/requirements.dart';
import 'checkout_button_style.dart';
import 'native_checkout_button.dart';

/// Consumer-facing wrapper that renders any unsatisfied ToS items above the
/// native [OnramperNativeCheckoutButton].
///
/// The native button is embedded inline via a Flutter platform view and handles
/// the full checkout flow (OIDC login, finalize, payment webview) without a
/// separate `presentCheckout()` call.
///
/// ToS links (when they carry a `url`) are opened with `url_launcher` in an
/// external browser, or routed through [onLinkTap] if provided.
class OnramperCheckoutButton extends StatefulWidget {
  const OnramperCheckoutButton({
    super.key,
    required this.requirements,
    this.style = const CheckoutButtonStyle(),
    this.onLinkTap,
  });

  final CheckoutRequirementsResult requirements;
  final CheckoutButtonStyle style;

  /// Optional override for opening ToS links. Useful in tests + custom in-app
  /// routing. When `null`, links are opened via `launchUrl` in an external
  /// browser.
  final Future<bool> Function(Uri)? onLinkTap;

  @override
  State<OnramperCheckoutButton> createState() => _OnramperCheckoutButtonState();
}

class _OnramperCheckoutButtonState extends State<OnramperCheckoutButton> {
  @override
  Widget build(BuildContext context) {
    final tosItems = _tosItems;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnramperNativeCheckoutButton(
          buttonHandle: widget.requirements.buttonHandle,
        ),
        if (tosItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...tosItems.map(
            (item) => _TosLine(
              item: item,
              style: widget.style,
              onLinkTap: widget.onLinkTap,
            ),
          ),
        ],
      ],
    );
  }

  List<TosItem> get _tosItems => widget.requirements.tos
      .expand((req) => req.items.where((i) => i.required && !i.satisfied))
      .toList(growable: false);
}

class _TosLine extends StatelessWidget {
  const _TosLine({required this.item, required this.style, this.onLinkTap});

  final TosItem item;
  final CheckoutButtonStyle style;
  final Future<bool> Function(Uri)? onLinkTap;

  @override
  Widget build(BuildContext context) {
    final label = item.type.displayName;
    final url = item.url;
    final defaultStyle = style.tosStyle ?? const TextStyle(fontSize: 12);
    final linkStyle = style.tosLinkStyle ??
        defaultStyle.copyWith(
          decoration: TextDecoration.underline,
          color: Colors.blue,
        );

    final isLink = url != null && url.isNotEmpty;
    final text = Text(label, style: isLink ? linkStyle : defaultStyle);

    if (!isLink) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: text,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onTap: () => unawaited(_openLink(Uri.parse(url))),
        child: text,
      ),
    );
  }

  Future<void> _openLink(Uri uri) async {
    if (onLinkTap != null) {
      await onLinkTap!(uri);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/requirements.dart';
import '../models/state.dart';
import '../onramper_client.dart';
import 'checkout_button_style.dart';

/// Consumer-facing Buy button + ToS renderer for the Onramper checkout flow.
///
/// Listens to [client] (a [ChangeNotifier]) and rebuilds on state changes.
/// Tapping the button calls [OnramperClient.presentCheckout]; the native side
/// renders the checkout webview. ToS items from [requirements] are rendered
/// underneath the button and (when they carry a `url`) opened with
/// `url_launcher` in an external browser.
///
/// While the client is in a "busy" state (`checkoutPreparing`,
/// `authenticating`, `finalizing`, or `rendering`), the button is disabled
/// and displays a small progress indicator.
class OnramperCheckoutButton extends StatefulWidget {
  const OnramperCheckoutButton({
    super.key,
    required this.client,
    required this.requirements,
    this.style = const CheckoutButtonStyle(),
    this.label = 'Buy',
    this.onLinkTap,
  });

  final OnramperClient client;
  final CheckoutRequirementsResult requirements;
  final CheckoutButtonStyle style;
  final String label;

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
    return AnimatedBuilder(
      animation: widget.client,
      builder: (context, _) {
        final busy = _isBusy(widget.client.state.kind);
        final tosItems = _tosItems;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () => unawaited(widget.client.presentCheckout()),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.style.backgroundColor,
                foregroundColor: widget.style.foregroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(widget.style.borderRadius),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.label, style: widget.style.labelStyle),
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
      },
    );
  }

  List<TosItem> get _tosItems {
    return widget.requirements.tos
        .expand((req) => req.items)
        .where((item) =>
            (item.content?.isNotEmpty ?? false) ||
            (item.url?.isNotEmpty ?? false))
        .toList(growable: false);
  }

  bool _isBusy(OnramperStateKind kind) => switch (kind) {
        OnramperStateKind.checkoutPreparing ||
        OnramperStateKind.authenticating ||
        OnramperStateKind.finalizing ||
        OnramperStateKind.rendering =>
          true,
        _ => false,
      };
}

class _TosLine extends StatelessWidget {
  const _TosLine({required this.item, required this.style, this.onLinkTap});

  final TosItem item;
  final CheckoutButtonStyle style;
  final Future<bool> Function(Uri)? onLinkTap;

  @override
  Widget build(BuildContext context) {
    final label = item.content ?? item.url ?? '';
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

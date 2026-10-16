import 'package:flutter/material.dart';

import '../theme/demo_theme.dart';
import 'spaced.dart';

enum StatusTone { success, error, info }

class StatusBox extends StatelessWidget {
  const StatusBox({
    super.key,
    required this.tone,
    required this.title,
    this.body,
    this.selectableBody = false,
    this.actionLabel,
    this.onAction,
  });

  final StatusTone tone;
  final String title;
  final String? body;
  final bool selectableBody;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    final color = switch (tone) {
      StatusTone.success => p.success,
      StatusTone.info => p.accent,
      StatusTone.error => p.danger,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.faded(0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(DemoRadius.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: spaced(6, [
          Text(title,
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.w600)),
          if (body != null)
            selectableBody
                ? SelectableText(body!,
                    style: TextStyle(
                        color: p.text, fontSize: 12, fontFamily: kMonoFont))
                : Text(body!, style: TextStyle(color: p.text, fontSize: 13)),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!,
                  style: TextStyle(
                      color: color, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }
}

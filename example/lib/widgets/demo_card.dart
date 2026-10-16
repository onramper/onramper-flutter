import 'package:flutter/material.dart';

import '../theme/demo_theme.dart';
import 'spaced.dart';

/// RN `Card`: padded rounded surface with optional title and footer.
class DemoCard extends StatelessWidget {
  const DemoCard({
    super.key,
    this.title,
    this.footer,
    required this.children,
    this.gap = 12,
  });

  final String? title;
  final String? footer;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(DemoRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaced(gap, [
          if (title != null)
            Text(title!,
                style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ...children,
          if (footer != null)
            Text(footer!,
                style: TextStyle(
                    color: p.textSecondary, fontSize: 12, height: 16 / 12)),
        ]),
      ),
    );
  }
}

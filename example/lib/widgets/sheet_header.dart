import 'package:flutter/material.dart';

import '../theme/demo_theme.dart';

/// RN `SheetHeader`: centred title, close mark on the leading edge, 56 high.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    // Full width even inside a non-stretching Column, so the close mark sits
    // on the leading edge and the title is centred on the sheet.
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Stack(alignment: Alignment.center, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: p.text, fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        Positioned(
          left: 16,
          child: Semantics(
            button: true,
            label: 'Close',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: SizedBox(
                width: 30,
                height: 30,
                child: Icon(Icons.close, size: 22, color: p.textSecondary),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

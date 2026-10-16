import 'package:flutter/material.dart';

import '../theme/demo_theme.dart';
import 'spaced.dart';

/// RN `Tile`: bordered choice; accent border + tint when selected.
class Tile extends StatelessWidget {
  const Tile({
    super.key,
    required this.label,
    this.sublabel,
    required this.selected,
    required this.onTap,
    this.leading,
    this.disabled = false,
  });

  final String label;
  final String? sublabel;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    final radius = BorderRadius.circular(DemoRadius.tile);
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: disabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? p.accent.faded(0.2) : null,
              border: Border.all(
                color: selected ? p.accent : p.border,
                width: selected ? 1.5 : 1,
              ),
              borderRadius: radius,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: spaced(4, [
                if (leading != null) leading!,
                Text(label,
                    style: TextStyle(
                        color: p.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (sublabel != null)
                  Text(sublabel!,
                      style: TextStyle(color: p.textSecondary, fontSize: 12)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class TileRow extends StatelessWidget {
  const TileRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
        children: spaced(8, [for (final c in children) Expanded(child: c)]),
      );
}

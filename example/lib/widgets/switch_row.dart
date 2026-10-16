import 'package:flutter/material.dart';

import '../theme/demo_theme.dart';

class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.disabled = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    return Row(children: [
      Expanded(
          child: Text(label, style: TextStyle(color: p.text, fontSize: 15))),
      Switch.adaptive(
        value: value,
        onChanged: disabled ? null : onChanged,
        activeTrackColor: p.accent,
      ),
    ]);
  }
}

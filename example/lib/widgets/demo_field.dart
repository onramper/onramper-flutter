import 'package:flutter/material.dart';

import '../theme/demo_theme.dart';
import 'spaced.dart';

/// RN `Field`: optional small label above a filled, borderless input.
class DemoField extends StatelessWidget {
  const DemoField({
    super.key,
    this.label,
    required this.controller,
    this.mono = false,
    this.enabled = true,
    this.placeholder,
    this.keyboardType,
    this.semanticsLabel,
    this.onChanged,
  });

  final String? label;
  final TextEditingController controller;
  final bool mono;
  final bool enabled;
  final String? placeholder;
  final TextInputType? keyboardType;
  final String? semanticsLabel;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaced(4, [
        if (label != null)
          Text(label!, style: TextStyle(color: p.textSecondary, fontSize: 12)),
        Semantics(
          label: semanticsLabel ?? label,
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: onChanged,
            cursorColor: p.accent,
            style: TextStyle(
              color: enabled ? p.text : p.textSecondary,
              fontSize: mono ? 13 : 15,
              fontFamily: mono ? kMonoFont : null,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: p.inputBg,
              hintText: placeholder,
              hintStyle: TextStyle(color: p.textSecondary),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DemoRadius.input),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

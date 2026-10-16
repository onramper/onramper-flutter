import 'package:flutter/material.dart';

import '../theme/demo_theme.dart';

class SegmentOption<T> {
  const SegmentOption(this.value, this.label);
  final T value;
  final String label;
}

/// RN `Segmented`: pill track with an accent-tinted selected segment.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.disabled = false,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: p.inputBg,
          borderRadius: BorderRadius.circular(DemoRadius.input),
        ),
        child: Row(children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: disabled ? null : () => onChanged(option.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: option.value == value
                        ? p.accent.withValues(alpha: 0.25)
                        : null,
                    borderRadius:
                        BorderRadius.circular(DemoRadius.input - 2),
                  ),
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: option.value == value ? p.text : p.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

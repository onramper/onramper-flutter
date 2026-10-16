import 'package:flutter/material.dart';

import '../theme/demo_theme.dart';
import 'segmented.dart';

/// RN `Dropdown`: a field showing the current choice; options open inline.
class DemoDropdown<T> extends StatefulWidget {
  const DemoDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  State<DemoDropdown<T>> createState() => _DemoDropdownState<T>();
}

class _DemoDropdownState<T> extends State<DemoDropdown<T>> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    final radius = BorderRadius.circular(DemoRadius.input);
    final current = widget.options
        .where((o) => o.value == widget.value)
        .map((o) => o.label)
        .firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        button: true,
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.inputBg, borderRadius: radius),
            child: Row(children: [
              Expanded(
                child: Text(current ?? '${widget.value}',
                    style: TextStyle(color: p.text, fontSize: 15)),
              ),
              Text(_open ? '▴' : '▾',
                  style: TextStyle(color: p.textSecondary, fontSize: 13)),
            ]),
          ),
        ),
      ),
      if (_open)
        Container(
          margin: const EdgeInsets.only(top: 6),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.cardBg,
            border: Border.all(color: p.border),
            borderRadius: radius,
          ),
          child: Column(children: [
            for (final (i, option) in widget.options.indexed)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _open = false);
                  if (option.value != widget.value) {
                    widget.onChanged(option.value);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: option.value == widget.value
                        ? p.accent.faded(0.15)
                        : null,
                    border: i == 0
                        ? null
                        : Border(top: BorderSide(color: p.border, width: 0.5)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(option.label,
                          style: TextStyle(color: p.text, fontSize: 15)),
                    ),
                    if (option.value == widget.value)
                      Text('✓',
                          style: TextStyle(
                              color: p.accent,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
        ),
    ]);
  }
}

import 'package:flutter/material.dart';

import '../theme/demo_theme.dart';
import 'page_sheet.dart';
import 'segmented.dart';
import 'sheet_header.dart';

Future<void> showOptionSheet(
  BuildContext context, {
  required String title,
  required List<SegmentOption<String>> options,
  required String selected,
  required ValueChanged<String> onSelect,
}) =>
    showPageSheet<void>(context, builder: (context) {
      final p = DemoTheme.of(context);
      return Column(children: [
        SheetHeader(title: title, onClose: () => Navigator.pop(context)),
        Expanded(
          child: ListView.builder(
            itemCount: options.length,
            itemBuilder: (context, i) {
              final option = options[i];
              return InkWell(
                onTap: () {
                  onSelect(option.value);
                  Navigator.pop(context);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: p.border, width: 0.5)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(option.label,
                          style: TextStyle(color: p.text, fontSize: 16)),
                    ),
                    if (option.value == selected)
                      Text('✓', style: TextStyle(color: p.accent)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]);
    });

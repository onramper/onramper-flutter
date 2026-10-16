import 'package:flutter/material.dart';

import '../logging/event_log.dart';
import '../theme/demo_theme.dart';
import 'demo_card.dart';

class EventLogCard extends StatefulWidget {
  const EventLogCard(
      {super.key, required this.log, this.initiallyOpen = false});

  final EventLog log;
  final bool initiallyOpen;

  @override
  State<EventLogCard> createState() => _EventLogCardState();
}

class _EventLogCardState extends State<EventLogCard> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    return ListenableBuilder(
      listenable: widget.log,
      builder: (context, _) {
        final entries = widget.log.entries;
        const line =
            TextStyle(fontFamily: kMonoFont, fontSize: 11, height: 15 / 11);
        Color colorFor(EventLevel level) => switch (level) {
              EventLevel.error => p.danger,
              EventLevel.event => p.accent,
              EventLevel.info => p.textSecondary,
            };
        return DemoCard(children: [
          Row(children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _open = !_open),
                child: Text(
                    'SDK events (${entries.length}) ${_open ? '▾' : '▸'}',
                    style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ),
            ),
            if (_open)
              GestureDetector(
                onTap: widget.log.clear,
                child: Text('Clear',
                    style: TextStyle(
                        color: p.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
          if (_open && entries.isEmpty)
            Text('(empty)', style: line.copyWith(color: p.textSecondary)),
          if (_open)
            for (final e in entries)
              SelectableText('${e.time} ${e.line}',
                  style: line.copyWith(color: colorFor(e.level))),
        ]);
      },
    );
  }
}

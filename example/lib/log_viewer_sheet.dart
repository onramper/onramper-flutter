import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'log_buffer.dart';

/// Bottom sheet listing captured SDK logs with Clear and Copy all.
/// Exported logs may contain personal data; share them carefully.
Future<void> showLogViewer(BuildContext context, LogBuffer buffer) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: ListenableBuilder(
          listenable: buffer,
          builder: (context, _) {
            final records = buffer.records.reversed.toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Text('SDK logs (${records.length})',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      TextButton(
                        onPressed: records.isEmpty ? null : buffer.clear,
                        child: const Text('Clear'),
                      ),
                      TextButton(
                        onPressed: records.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                    ClipboardData(text: buffer.toJsonLines()));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Logs copied')),
                                  );
                                }
                              },
                        child: const Text('Copy all'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: records.isEmpty
                      ? const Center(child: Text('No logs yet'))
                      : ListView.builder(
                          itemCount: records.length,
                          itemBuilder: (context, i) {
                            final r = records[i];
                            return ExpansionTile(
                              dense: true,
                              title: Text(
                                '${r.timestamp.toIso8601String().substring(11, 23)} '
                                '${r.level.name.toUpperCase()} '
                                '${r.category} · ${r.event}',
                                style: const TextStyle(
                                    fontSize: 12, fontFamily: 'Courier'),
                              ),
                              subtitle: Text(r.message,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11)),
                              children: [
                                for (final e in r.context.entries)
                                  ListTile(
                                    dense: true,
                                    title: Text('${e.key} = ${e.value}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'Courier')),
                                  ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

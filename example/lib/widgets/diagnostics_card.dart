import 'package:flutter/material.dart';

import '../logging/log_file_store.dart';
import '../logging/log_settings.dart';
import '../logging/share_log_file.dart';
import '../screens/log_preview_sheet.dart';
import '../theme/demo_theme.dart';
import 'demo_card.dart';
import 'page_sheet.dart';
import 'switch_row.dart';

String fileSize(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).ceil()} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// Rect of [context]'s render box in global coordinates (share popover anchor).
Rect? originOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// RN `DiagnosticsCard`.
class DiagnosticsCard extends StatefulWidget {
  const DiagnosticsCard({
    super.key,
    required this.settings,
    required this.store,
    required this.share,
  });

  final LogSettings settings;
  final LogFileStore store;
  final ShareLogFile share;

  @override
  State<DiagnosticsCard> createState() => _DiagnosticsCardState();
}

class _DiagnosticsCardState extends State<DiagnosticsCard> {
  List<LogFile> _files = const [];
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run(() async => _files = await widget.store.listFiles(),
        failure: 'Could not load diagnostic logs.');
  }

  /// Called from initState too: `_busy` starts true there, so no setState
  /// happens before the first build.
  Future<void> _run(Future<void> Function() action,
      {String failure = 'Could not update diagnostic logs.'}) async {
    if (!_busy) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _error = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final p = DemoTheme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Delete all logs?'),
        content: const Text(
            'This permanently deletes all saved diagnostic logs on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete all', style: TextStyle(color: p.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await widget.store.deleteAll();
      _files = await widget.store.listFiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    final total = _files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    return DemoCard(
      title: 'Diagnostic logs',
      footer: 'Logging is on by default. Daily files use UTC dates and stay on this '
          'device until shared. Logs are kept for up to 7 days and 5 MB; older '
          'entries are removed first. Provider messages may contain personal '
          'information.',
      children: [
        ListenableBuilder(
          listenable: widget.settings,
          builder: (context, _) => SwitchRow(
            label: 'Save SDK logs',
            value: widget.settings.enabled,
            disabled: _busy,
            onChanged: (v) => _run(() => widget.settings.setEnabled(v)),
          ),
        ),
        Row(children: [
          Expanded(
            child: Text('${_files.length} files · ${fileSize(total)}',
                style: TextStyle(color: p.textSecondary)),
          ),
          GestureDetector(
            onTap: _busy
                ? null
                : () => _run(() async => _files = await widget.store.listFiles()),
            child: Text('Refresh', style: TextStyle(color: p.accent)),
          ),
        ]),
        if (_files.isEmpty && !_busy)
          Text('No log files yet.', style: TextStyle(color: p.textSecondary)),
        for (final file in _files)
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.border, width: 0.5))),
            child: Row(spacing: 12, children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _busy
                      ? null
                      : () => showPageSheet<void>(context,
                          builder: (_) => LogPreviewSheet(
                              file: file,
                              store: widget.store,
                              share: widget.share)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(file.name, style: TextStyle(color: p.text)),
                    const SizedBox(height: 4),
                    Text('${fileSize(file.sizeBytes)} · UTC',
                        style: TextStyle(color: p.textSecondary, fontSize: 12)),
                  ]),
                ),
              ),
              Builder(
                builder: (shareContext) => GestureDetector(
                  onTap: _busy
                      ? null
                      : () {
                          final origin = originOf(shareContext);
                          _run(() async {
                            final copy = await widget.store.snapshot(file);
                            await widget.share(copy, origin);
                          });
                        },
                  child: Text('Share', style: TextStyle(color: p.accent)),
                ),
              ),
            ]),
          ),
        if (_busy) Center(child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation(p.accent))),
        GestureDetector(
          onTap: _busy || _files.isEmpty ? null : _confirmDelete,
          child: Text('Delete all logs',
              style: TextStyle(
                  color: _files.isEmpty ? p.textSecondary : p.danger)),
        ),
        if (_error != null) Text(_error!, style: TextStyle(color: p.danger)),
      ],
    );
  }
}

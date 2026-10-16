import 'package:flutter/material.dart';

import '../logging/log_file_store.dart';
import '../logging/share_log_file.dart';
import '../theme/demo_theme.dart';
import '../widgets/diagnostics_card.dart' show originOf;
import '../widgets/sheet_header.dart';
import '../widgets/spaced.dart';

class LogPreviewSheet extends StatefulWidget {
  const LogPreviewSheet({
    super.key,
    required this.file,
    required this.store,
    required this.share,
  });

  final LogFile file;
  final LogFileStore store;
  final ShareLogFile share;

  @override
  State<LogPreviewSheet> createState() => _LogPreviewSheetState();
}

class _LogPreviewSheetState extends State<LogPreviewSheet> {
  String _text = '';
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run(() async => _text = await widget.store.preview(widget.file));
  }

  /// Called from initState too: `_busy` starts true there, so no setState
  /// happens before the first build.
  Future<void> _run(Future<void> Function() action) async {
    if (!_busy) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not update diagnostic logs.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetHeader(title: 'Log preview', onClose: () => Navigator.pop(context)),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
            children: spaced(12, [
          Expanded(
              child: Text(widget.file.name, style: TextStyle(color: p.text))),
          Builder(
            builder: (shareContext) => GestureDetector(
              onTap: _busy
                  ? null
                  : () {
                      final origin = originOf(shareContext);
                      _run(() => widget.store.withSnapshot(
                          widget.file, (copy) => widget.share(copy, origin)));
                    },
              child: Text('Share', style: TextStyle(color: p.accent)),
            ),
          ),
        ])),
      ),
      if (_busy)
        Center(
            child: CircularProgressIndicator.adaptive(
                valueColor: AlwaysStoppedAnimation(p.accent))),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: TextStyle(color: p.danger)),
        ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          child: SelectableText(
            _text.isEmpty && !_busy ? '(empty)' : _text,
            style: TextStyle(
                color: p.text,
                fontFamily: kMonoFont,
                fontSize: 12,
                height: 18 / 12),
          ),
        ),
      ),
    ]);
  }
}

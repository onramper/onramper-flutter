import 'dart:async';

import 'package:flutter/widgets.dart';

/// RN `TYPING_DEBOUNCE_MS`.
const typingDebounce = Duration(milliseconds: 400);

/// A text draft that commits [typingDebounce] after typing stops (RN
/// `useDebouncedField`). An outside change of the committed value replaces the
/// draft immediately; re-syncing the value it already holds is a no-op, so an
/// uncommitted draft is never overwritten.
class DebouncedText {
  DebouncedText({
    required String initial,
    required this.onCommit,
    this.delay = typingDebounce,
  })  : controller = TextEditingController(text: initial),
        _committed = initial;

  final TextEditingController controller;
  final ValueChanged<String> onCommit;
  final Duration delay;
  String _committed;
  Timer? _timer;

  void onChanged(String _) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _committed = controller.text;
      onCommit(_committed);
    });
  }

  void sync(String committed) {
    if (committed == _committed) return;
    _committed = committed;
    _timer?.cancel();
    if (controller.text != committed) controller.text = committed;
  }

  void dispose() {
    _timer?.cancel();
    controller.dispose();
  }
}

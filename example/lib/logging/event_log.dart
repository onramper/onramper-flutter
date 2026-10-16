import 'package:flutter/foundation.dart';

enum EventLevel { info, event, error }

@immutable
class LogEntry {
  const LogEntry({
    required this.id,
    required this.time,
    required this.level,
    required this.line,
  });

  final int id;

  /// `HH:MM:SS` in UTC.
  final String time;
  final EventLevel level;
  final String line;
}

/// In-memory list of the demo's own log lines (RN `useOnramper` log).
/// Not written to files — SDK records go to the LogFileStore.
class EventLog extends ChangeNotifier {
  EventLog({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const maxEntries = 300;

  final DateTime Function() _clock;
  final List<LogEntry> _entries = [];
  int _nextId = 0;

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void add(EventLevel level, String line) {
    _entries.add(LogEntry(
      id: _nextId++,
      time: _clock().toUtc().toIso8601String().substring(11, 19),
      level: level,
      line: line,
    ));
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    notifyListeners();
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }
}

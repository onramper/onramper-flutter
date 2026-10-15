import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

/// In-memory ring buffer fed by `OnramperConfiguration.logHandler`.
class LogBuffer extends ChangeNotifier {
  LogBuffer({this.capacity = 1000});

  final int capacity;
  final ListQueue<OnramperLogRecord> _records = ListQueue();

  List<OnramperLogRecord> get records => List.unmodifiable(_records);

  void add(OnramperLogRecord record) {
    if (_records.length >= capacity) _records.removeFirst();
    _records.addLast(record);
    notifyListeners();
  }

  void clear() {
    _records.clear();
    notifyListeners();
  }

  /// One JSON object per line, oldest first.
  String toJsonLines() => _records
      .map((r) => jsonEncode({
            'timestamp': r.timestamp.toIso8601String(),
            'level': r.level.name,
            'category': r.category,
            'event': r.event,
            'context': r.context,
            'message': r.message,
          }))
      .join('\n');
}

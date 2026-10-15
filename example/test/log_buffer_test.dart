import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter_example/log_buffer.dart';

OnramperLogRecord _rec(String event) => OnramperLogRecord(
      timestamp: DateTime.utc(2026, 10, 15),
      level: OnramperLogLevel.info,
      category: 'Checkout',
      event: event,
      context: const {'k': 'v'},
      message: '$event k=v',
    );

void main() {
  test('keeps only the last `capacity` records', () {
    final b = LogBuffer(capacity: 2)
      ..add(_rec('a'))
      ..add(_rec('b'))
      ..add(_rec('c'));
    expect(b.records.map((r) => r.event), ['b', 'c']);
  });

  test('toJsonLines emits one JSON object per record', () {
    final b = LogBuffer()..add(_rec('a'));
    final line = jsonDecode(b.toJsonLines().trim()) as Map<String, dynamic>;
    expect(line['event'], 'a');
    expect(line['level'], 'info');
    expect(line['context'], {'k': 'v'});
    expect(line['timestamp'], '2026-10-15T00:00:00.000Z');
  });

  test('clear empties and notifies', () {
    var n = 0;
    final b = LogBuffer()..add(_rec('a'));
    b.addListener(() => n++);
    b.clear();
    expect(b.records, isEmpty);
    expect(n, 1);
  });
}

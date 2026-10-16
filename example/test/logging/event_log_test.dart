import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter_example/logging/event_log.dart';

void main() {
  test('stamps HH:MM:SS UTC and keeps the newest 300', () {
    final log = EventLog(clock: () => DateTime.utc(2026, 10, 16, 9, 5, 7));
    for (var i = 0; i < 305; i++) {
      log.add(EventLevel.info, 'line $i');
    }
    expect(log.entries.length, EventLog.maxEntries);
    expect(log.entries.first.line, 'line 5');
    expect(log.entries.last.time, '09:05:07');
    expect(log.entries.last.id, 304);
  });

  test('add and clear notify', () {
    final log = EventLog();
    var notified = 0;
    log.addListener(() => notified++);
    log.add(EventLevel.error, 'x');
    log.clear();
    log.clear();
    expect(notified, 2);
    expect(log.entries, isEmpty);
  });
}

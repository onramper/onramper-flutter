import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter_example/logging/log_file_store.dart';

void main() {
  late Directory root;
  late Directory logs;
  setUp(() {
    root = Directory.systemTemp.createTempSync('log_store_test');
    logs = Directory('${root.path}/Logs');
  });
  tearDown(() => root.deleteSync(recursive: true));

  LogFileStore store(
          {int maxBytes = 5 * 1024 * 1024, int previewBytes = 200 * 1024}) =>
      LogFileStore(
        directory: () async => logs,
        launchHeader: () async => 'appVersion=1 build=2 device=x ios=18',
        shareDirectory: () async => Directory('${root.path}/share'),
        maxBytes: maxBytes,
        previewBytes: previewBytes,
      );

  File day(String d) => File('${logs.path}/onramper-sdk-$d.log');

  void seed(String d, String content) {
    logs.createSync(recursive: true);
    day(d).writeAsStringSync(content);
  }

  test('writes a launch header once, then escaped lines, in a UTC-day file',
      () async {
    final s = store();
    await s.write(
        at: DateTime.utc(2026, 10, 16, 10, 0, 0, 123),
        level: 'info',
        category: 'Checkout',
        message: 'a\nb\rc');
    await s.write(
        at: DateTime.utc(2026, 10, 16, 10, 0, 1),
        level: 'debug',
        category: 'Net',
        message: 'ok');
    final lines = day('2026-10-16').readAsLinesSync();
    expect(lines, [
      '2026-10-16T10:00:00.123Z INFO DemoApp app.launch appVersion=1 build=2 device=x ios=18',
      r'2026-10-16T10:00:00.123Z INFO Checkout a\nb\rc',
      '2026-10-16T10:00:01.000Z DEBUG Net ok',
    ]);
  });

  test('splits files by UTC day', () async {
    final s = store();
    await s.write(
        at: DateTime.utc(2026, 10, 16, 23, 59),
        level: 'info',
        category: 'c',
        message: 'late');
    await s.write(
        at: DateTime.utc(2026, 10, 17, 0, 1),
        level: 'info',
        category: 'c',
        message: 'early');
    expect(day('2026-10-16').readAsStringSync(), contains('late'));
    expect(day('2026-10-17').readAsStringSync(), contains('early'));
  });

  test('drops records over the size cap', () async {
    final s = store();
    await s.write(
        at: DateTime.utc(2026, 10, 16),
        level: 'info',
        category: 'c',
        message: 'x' * 70000);
    final text = day('2026-10-16').readAsStringSync();
    expect(text, contains('app.launch'));
    expect(text, isNot(contains('xxxxxxxxxx')));
  });

  test('formatRecordMessage writes the native message once', () {
    // The native SDK's message is already "<event> k1=v1 …" (keys sorted).
    final r = OnramperLogRecord(
      timestamp: DateTime.utc(2026),
      level: OnramperLogLevel.info,
      category: 'Checkout',
      event: 'checkout.finalized',
      context: const {'ramp': 'moonpay', 'id': 'x'},
      message: 'checkout.finalized id=x ramp=moonpay',
    );
    expect(formatRecordMessage(r), 'checkout.finalized id=x ramp=moonpay');
  });

  test('formatRecordMessage falls back to the event for an empty message', () {
    final r = OnramperLogRecord(
      timestamp: DateTime.utc(2026),
      level: OnramperLogLevel.info,
      category: 'Checkout',
      event: 'checkout.started',
      context: const {},
      message: '',
    );
    expect(formatRecordMessage(r), 'checkout.started');
  });

  test('prunes files older than 7 days on the first write', () async {
    seed('2026-10-09', 'old\n');
    seed('2026-10-10', 'keep\n');
    await store().write(
        at: DateTime.utc(2026, 10, 16),
        level: 'info',
        category: 'c',
        message: 'm');
    expect(day('2026-10-09').existsSync(), isFalse);
    expect(day('2026-10-10').existsSync(), isTrue);
  });

  test('deletes oldest files while over the size cap', () async {
    seed('2026-10-14', 'a' * 199 + '\n');
    seed('2026-10-15', 'b' * 199 + '\n');
    await store(maxBytes: 350).write(
        at: DateTime.utc(2026, 10, 16),
        level: 'info',
        category: 'c',
        message: 'm');
    expect(day('2026-10-14').existsSync(), isFalse);
    expect(day('2026-10-15').existsSync(), isTrue);
  });

  test('tail-trims a single oversized file with a notice', () async {
    seed('2026-10-16',
        '${List.generate(40, (i) => 'line-${i.toString().padLeft(3, '0')}').join('\n')}\n');
    await store(maxBytes: 300).write(
        at: DateTime.utc(2026, 10, 16),
        level: 'info',
        category: 'c',
        message: 'm');
    final text = day('2026-10-16').readAsStringSync();
    expect(text, startsWith('… trimmed to the newest entries …\n'));
    expect(text, isNot(contains('line-000')));
    expect(text, contains('line-039'));
  });

  test('enforces the size cap while writing, not only at launch', () async {
    final s = store(maxBytes: 300);
    for (var i = 0; i < 50; i++) {
      await s.write(
          at: DateTime.utc(2026, 10, 16, 10, 0, i),
          level: 'info',
          category: 'c',
          message: 'record-$i');
    }
    expect(day('2026-10-16').lengthSync(), lessThanOrEqualTo(360));
    expect(day('2026-10-16').readAsStringSync(), contains('record-49'));
  });

  test('lists newest first and ignores other files', () async {
    seed('2026-10-14', 'a\n');
    seed('2026-10-15', 'b\n');
    File('${logs.path}/notes.txt').writeAsStringSync('x');
    final files = await store().listFiles();
    expect(files.map((f) => f.name),
        ['onramper-sdk-2026-10-15.log', 'onramper-sdk-2026-10-14.log']);
    expect(files.first.sizeBytes, 2);
  });

  test('preview returns the tail without a partial first line', () async {
    seed('2026-10-16', '${List.generate(10, (i) => 'line-$i').join('\n')}\n');
    final s = store(previewBytes: 20);
    final text = await s.preview((await s.listFiles()).single);
    expect(text, startsWith('… showing the last'));
    final body = text.split('\n').skip(1).where((l) => l.isNotEmpty);
    expect(body, everyElement(matches(RegExp(r'^line-\d$'))));
    expect(body.last, 'line-9');
  });

  test('small files preview in full', () async {
    seed('2026-10-16', 'one\ntwo\n');
    final s = store();
    expect(await s.preview((await s.listFiles()).single), 'one\ntwo\n');
  });

  test('snapshot copies into the share directory', () async {
    seed('2026-10-16', 'data\n');
    final s = store();
    final copy = await s.snapshot((await s.listFiles()).single);
    expect(copy.path, startsWith('${root.path}/share'));
    expect(copy.readAsStringSync(), 'data\n');
  });

  test('deleteAll removes every log file', () async {
    seed('2026-10-15', 'a\n');
    seed('2026-10-16', 'b\n');
    final s = store();
    await s.deleteAll();
    expect(await s.listFiles(), isEmpty);
  });

  test('excludes the directory from backup once and survives failures',
      () async {
    final excluded = <String>[];
    final s = LogFileStore(
      directory: () async => logs,
      excludeFromBackup: (path) async {
        excluded.add(path);
        throw Exception('nope');
      },
    );
    await s.write(
        at: DateTime.utc(2026, 10, 16),
        level: 'info',
        category: 'c',
        message: 'm');
    await s.write(
        at: DateTime.utc(2026, 10, 16),
        level: 'info',
        category: 'c',
        message: 'n');
    expect(excluded, [logs.path]);
    expect(day('2026-10-16').readAsStringSync(), contains(' c n'));
  });
}

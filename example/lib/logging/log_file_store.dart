import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

class LogFile {
  const LogFile({
    required this.file,
    required this.sizeBytes,
    required this.modified,
  });

  final File file;
  final int sizeBytes;

  /// Last modification, UTC.
  final DateTime modified;

  String get name => file.uri.pathSegments.last;
}

/// The record's text for one log line. The native SDK's `message` is already
/// `<event> k1=v1 …` (keys sorted), so it's written as-is, as RN does.
String formatRecordMessage(OnramperLogRecord r) =>
    r.message.isEmpty ? r.event : r.message;

/// Daily SDK log files — a Dart port of the RN demo's `DemoDailyLogStore`.
/// Every operation runs through one queue, so writes never interleave with
/// listing, pruning or deleting.
class LogFileStore {
  LogFileStore({
    required Future<Directory> Function() directory,
    Future<String> Function()? launchHeader,
    Future<void> Function(String path)? excludeFromBackup,
    Future<Directory> Function()? shareDirectory,
    this.maxAge = const Duration(days: 7),
    this.maxBytes = 5 * 1024 * 1024,
    this.maxRecordBytes = 64 * 1024,
    this.previewBytes = 200 * 1024,
  })  : _directory = directory,
        _launchHeader = launchHeader,
        _excludeFromBackup = excludeFromBackup,
        _shareDirectory = shareDirectory ?? (() async => Directory.systemTemp);

  static const trimNotice = '… trimmed to the newest entries …\n';
  static final _namePattern =
      RegExp(r'^onramper-sdk-(\d{4}-\d{2}-\d{2})\.log$');

  final Future<Directory> Function() _directory;
  final Future<String> Function()? _launchHeader;
  final Future<void> Function(String path)? _excludeFromBackup;
  final Future<Directory> Function() _shareDirectory;
  final Duration maxAge;
  final int maxBytes;
  final int maxRecordBytes;
  final int previewBytes;

  Future<void> _tail = Future.value();
  Directory? _dir;
  String? _day;

  /// Running size of all log files; pruning recomputes it.
  int _totalBytes = 0;
  bool _headerWritten = false;

  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> append(OnramperLogRecord record) => write(
        at: record.timestamp,
        level: record.level.name,
        category: record.category,
        message: formatRecordMessage(record),
      );

  Future<void> write({
    required DateTime at,
    required String level,
    required String category,
    required String message,
  }) =>
      _serial(() async {
        try {
          final dir = await _ensureDir();
          final day = _dayOf(at);
          if (day != _day) {
            _day = day;
            await _prune(dir, day);
          }
          final buffer = StringBuffer();
          if (!_headerWritten) {
            _headerWritten = true;
            final header = await _header();
            buffer.writeln(_line(at, 'info', 'DemoApp',
                header.isEmpty ? 'app.launch' : 'app.launch $header'));
          }
          final line = _line(at, level, category, message);
          if (utf8.encode(line).length <= maxRecordBytes) buffer.writeln(line);
          if (buffer.isEmpty) return;
          final text = buffer.toString();
          await File('${dir.path}/onramper-sdk-$day.log')
              .writeAsString(text, mode: FileMode.append);
          // Enforce the cap during the session too, as RN does per append.
          _totalBytes += utf8.encode(text).length;
          if (_totalBytes > maxBytes) await _prune(dir, day);
        } catch (e) {
          debugPrint('LogFileStore: write failed: $e');
        }
      });

  /// Newest first.
  Future<List<LogFile>> listFiles() =>
      _serial(() async => (await _scan(await _ensureDir())).reversed.toList());

  /// The file's text, or its last [previewBytes] behind a marker line.
  Future<String> preview(LogFile file) => _serial(() async {
        final raf = await file.file.open();
        try {
          final length = await raf.length();
          if (length <= previewBytes) {
            return utf8.decode(await raf.read(length), allowMalformed: true);
          }
          await raf.setPosition(length - previewBytes);
          var text =
              utf8.decode(await raf.read(previewBytes), allowMalformed: true);
          final newline = text.indexOf('\n');
          if (newline >= 0) text = text.substring(newline + 1);
          return '… showing the last ${previewBytes ~/ 1024} KB …\n$text';
        } finally {
          await raf.close();
        }
      });

  /// A copy to hand to the share sheet, so later writes can't change it.
  Future<File> snapshot(LogFile file) => _serial(() async {
        final dir =
            Directory('${(await _shareDirectory()).path}/onramper-log-share');
        await dir.create(recursive: true);
        return file.file.copy('${dir.path}/${file.name}');
      });

  Future<void> deleteAll() => _serial(() async {
        for (final f in await _scan(await _ensureDir())) {
          await f.file.delete();
        }
      });

  Future<Directory> _ensureDir() async {
    final existing = _dir;
    if (existing != null) return existing;
    final dir = await _directory();
    await dir.create(recursive: true);
    try {
      await _excludeFromBackup?.call(dir.path);
    } catch (e) {
      debugPrint('LogFileStore: excludeFromBackup failed: $e');
    }
    return _dir = dir;
  }

  Future<String> _header() async {
    try {
      return await _launchHeader?.call() ?? '';
    } catch (_) {
      return 'appVersion=? build=? device=? ios=?';
    }
  }

  Future<void> _prune(Directory dir, String today) async {
    final cutoff =
        _dayOf(DateTime.parse('${today}T00:00:00Z').subtract(maxAge));
    final files = <LogFile>[];
    for (final f in await _scan(dir)) {
      if (_namePattern.firstMatch(f.name)!.group(1)!.compareTo(cutoff) <= 0) {
        await f.file.delete();
      } else {
        files.add(f);
      }
    }
    var total = files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    while (total > maxBytes && files.length > 1) {
      final oldest = files.removeAt(0);
      await oldest.file.delete();
      total -= oldest.sizeBytes;
    }
    if (total > maxBytes && files.length == 1) {
      total = await _trim(files.single);
    }
    _totalBytes = total;
  }

  /// Keeps the newest ~90% of the cap, so the next trim is some way off
  /// rather than on every following write. Returns the new size.
  Future<int> _trim(LogFile f) async {
    final bytes = await f.file.readAsBytes();
    final notice = utf8.encode(trimNotice);
    var keep =
        bytes.sublist(bytes.length - (maxBytes * 9 ~/ 10 - notice.length));
    final newline = keep.indexOf(10);
    if (newline >= 0) keep = keep.sublist(newline + 1);
    await f.file.writeAsBytes([...notice, ...keep], flush: true);
    return notice.length + keep.length;
  }

  Future<List<LogFile>> _scan(Directory dir) async {
    if (!await dir.exists()) return [];
    final out = <LogFile>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!_namePattern.hasMatch(entity.uri.pathSegments.last)) continue;
      final stat = await entity.stat();
      out.add(LogFile(
          file: entity, sizeBytes: stat.size, modified: stat.modified.toUtc()));
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  static String _dayOf(DateTime at) =>
      at.toUtc().toIso8601String().substring(0, 10);

  static String _line(
          DateTime at, String level, String category, String message) =>
      '${at.toUtc().toIso8601String()} ${level.toUpperCase()} $category '
      '${message.replaceAll('\r', r'\r').replaceAll('\n', r'\n')}';
}

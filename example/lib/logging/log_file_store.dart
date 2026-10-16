import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
    DateTime Function()? clock,
    this.maxAge = const Duration(days: 7),
    this.maxBytes = 5 * 1024 * 1024,
    this.maxRecordBytes = 64 * 1024,
    this.previewBytes = 200 * 1024,
  })  : _directory = directory,
        _launchHeader = launchHeader,
        _excludeFromBackup = excludeFromBackup,
        _clock = clock ?? DateTime.now,
        _shareDirectory = shareDirectory ?? (() async => Directory.systemTemp);

  static const trimNotice = '… trimmed to the newest entries …\n';
  static final _namePattern =
      RegExp(r'^onramper-sdk-(\d{4}-\d{2}-\d{2})\.log$');

  final Future<Directory> Function() _directory;
  final Future<String> Function()? _launchHeader;
  final Future<void> Function(String path)? _excludeFromBackup;
  final Future<Directory> Function() _shareDirectory;
  final DateTime Function() _clock;
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

  /// The day file kept open for appends; closed before any file is deleted
  /// or rewritten, and reopened by the next write.
  RandomAccessFile? _sink;
  String? _sinkPath;

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

  /// Apply retention and remove abandoned exports even when saving is off.
  Future<void> initialize() => _serial(() async {
        await _prepareRead();
      });

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
          final out = BytesBuilder(copy: false);
          if (!_headerWritten) {
            _headerWritten = true;
            final header = await _header();
            out.add(utf8.encode(
                '${_line(at, 'info', 'DemoApp', header.isEmpty ? 'app.launch' : 'app.launch $header')}\n'));
          }
          final line = utf8.encode('${_line(at, level, category, message)}\n');
          if (line.length - 1 <= maxRecordBytes) out.add(line);
          if (out.isEmpty) return;
          final bytes = out.takeBytes();
          final sink = await _openSink('${dir.path}/onramper-sdk-$day.log');
          try {
            await sink.writeFrom(bytes);
          } catch (_) {
            await _closeSink();
            rethrow;
          }
          // Enforce the cap during the session too, as RN does per append.
          _totalBytes += bytes.length;
          if (_totalBytes > maxBytes) await _prune(dir, day);
        } catch (e) {
          debugPrint('LogFileStore: write failed: $e');
        }
      });

  /// Newest first.
  Future<List<LogFile>> listFiles() => _serial(() async {
        final dir = await _prepareRead();
        return (await _scan(dir)).reversed.toList();
      });

  /// The file's text, or its last [previewBytes] behind a marker line.
  Future<String> preview(LogFile file) => _serial(() async {
        await _prepareRead();
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
  /// Use [withSnapshot] to release it after sharing.
  Future<File> snapshot(LogFile file) => _serial(() async {
        await _prepareRead();
        final dir =
            Directory('${(await _shareDirectory()).path}/onramper-log-share');
        await dir.create(recursive: true);
        final export = await dir.createTemp('share-');
        try {
          return await file.file.copy('${export.path}/${file.name}');
        } catch (_) {
          await export.delete(recursive: true);
          rethrow;
        }
      });

  /// Keep the copy until the share sheet finishes (including cancellation or
  /// failure), without holding up the store's queue while the sheet is open.
  Future<void> withSnapshot(
      LogFile file, Future<void> Function(File copy) share) async {
    final copy = await snapshot(file);
    try {
      await share(copy);
    } finally {
      await _serial(() async {
        if (await copy.parent.exists()) {
          await copy.parent.delete(recursive: true);
        }
      });
    }
  }

  Future<void> deleteAll() => _serial(() async {
        await _closeSink();
        for (final f in await _scan(await _ensureDir())) {
          await f.file.delete();
        }
        // The next file starts fresh: launch line first, nothing counted yet.
        _headerWritten = false;
        _totalBytes = 0;
        await _clearExports();
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
    // Anything left from a previous launch is no longer being shared.
    await _clearExports();
    return _dir = dir;
  }

  Future<Directory> _prepareRead() async {
    final dir = await _ensureDir();
    await _prune(dir, _dayOf(_clock()));
    return dir;
  }

  Future<void> _clearExports() async {
    final dir =
        Directory('${(await _shareDirectory()).path}/onramper-log-share');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<String> _header() async {
    try {
      return await _launchHeader?.call() ?? '';
    } catch (_) {
      return 'appVersion=? build=? device=? ios=?';
    }
  }

  Future<RandomAccessFile> _openSink(String path) async {
    final open = _sink;
    if (open != null && _sinkPath == path) return open;
    await _closeSink();
    final sink = await File(path).open(mode: FileMode.append);
    _sinkPath = path;
    return _sink = sink;
  }

  Future<void> _closeSink() async {
    final sink = _sink;
    _sink = null;
    _sinkPath = null;
    try {
      await sink?.close();
    } catch (e) {
      debugPrint('LogFileStore: close failed: $e');
    }
  }

  Future<void> _prune(Directory dir, String today) async {
    await _closeSink();
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

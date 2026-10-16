import 'dart:io';

import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter_example/logging/log_file_store.dart';

/// In-memory store: widget tests run in a fake-async zone where real file
/// I/O never completes.
class FakeLogFileStore extends LogFileStore {
  FakeLogFileStore() : super(directory: () async => Directory.systemTemp);

  final appended = <OnramperLogRecord>[];
  List<LogFile> files = [];
  String previewText = 'line one\nline two';
  bool deleted = false;

  @override
  Future<void> append(OnramperLogRecord record) async => appended.add(record);

  @override
  Future<List<LogFile>> listFiles() async => List.of(files);

  @override
  Future<String> preview(LogFile file) async => previewText;

  @override
  Future<File> snapshot(LogFile file) async => file.file;

  @override
  Future<void> withSnapshot(LogFile file, Future<void> Function(File) share) =>
      share(file.file);

  @override
  Future<void> deleteAll() async {
    deleted = true;
    files = [];
  }
}

LogFile fakeLogFile(String day, int size) => LogFile(
      file: File('/tmp/onramper-sdk-$day.log'),
      sizeBytes: size,
      modified: DateTime.utc(2026, 10, 16),
    );

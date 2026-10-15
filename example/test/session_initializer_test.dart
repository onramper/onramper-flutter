import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter_example/session_initializer.dart';

void main() {
  test('initializes once; later prepares (e.g. after reset) skip it', () async {
    var calls = 0;
    final s = SessionInitializer();
    await s.ensureInitialized(() async => calls++);
    await s.ensureInitialized(() async => calls++);
    expect(calls, 1);
  });

  test('a failed initialize is retried on the next prepare', () async {
    var calls = 0;
    final s = SessionInitializer();
    await expectLater(
      s.ensureInitialized(() async {
        calls++;
        throw StateError('attest failed');
      }),
      throwsStateError,
    );
    await s.ensureInitialized(() async => calls++);
    expect(calls, 2);
  });

  test('overlapping prepares share one initialize', () async {
    var calls = 0;
    final gate = Completer<void>();
    final s = SessionInitializer();
    final a = s.ensureInitialized(() async {
      calls++;
      await gate.future;
    });
    final b = s.ensureInitialized(() async => calls++);
    gate.complete();
    await Future.wait([a, b]);
    expect(calls, 1);
  });
}

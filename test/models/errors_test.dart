import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_sdk/src/models/errors.dart';
import 'package:onramper_sdk/src/platform/pigeon.g.dart';

void main() {
  group('OnramperError.fromDto', () {
    test('preserves all 13 fields', () {
      final dto = OnramperErrorDto(
        kind: OnramperErrorKindDto.amountOutOfRange,
        message: 'amount too low',
        recoverable: true,
        code: 42,
        minAmount: 10.0,
        maxAmount: 1000.0,
        retryAfterSeconds: 30.5,
        field: 'amount',
        debugInfo: 'min 10',
        fromState: 'ready',
        toState: 'failed',
        expectedState: 'rendering',
        actualState: 'completed',
      );

      final err = OnramperError.fromDto(dto);

      expect(err.kind, OnramperErrorKind.amountOutOfRange);
      expect(err.message, 'amount too low');
      expect(err.recoverable, true);
      expect(err.code, 42);
      expect(err.minAmount, 10.0);
      expect(err.maxAmount, 1000.0);
      expect(err.retryAfterSeconds, 30.5);
      expect(err.field, 'amount');
      expect(err.debugInfo, 'min 10');
      expect(err.fromState, 'ready');
      expect(err.toState, 'failed');
      expect(err.expectedState, 'rendering');
      expect(err.actualState, 'completed');
    });

    test('preserves null optional payloads', () {
      final dto = OnramperErrorDto(
        kind: OnramperErrorKindDto.networkError,
        message: 'oops',
        recoverable: false,
      );

      final err = OnramperError.fromDto(dto);

      expect(err.code, isNull);
      expect(err.minAmount, isNull);
      expect(err.maxAmount, isNull);
      expect(err.retryAfterSeconds, isNull);
      expect(err.field, isNull);
      expect(err.debugInfo, isNull);
      expect(err.fromState, isNull);
      expect(err.toState, isNull);
      expect(err.expectedState, isNull);
      expect(err.actualState, isNull);
    });

    test('every OnramperErrorKindDto maps to a non-null OnramperErrorKind', () {
      for (final dtoKind in OnramperErrorKindDto.values) {
        final dto = OnramperErrorDto(
          kind: dtoKind,
          message: 'm',
          recoverable: false,
        );
        final err = OnramperError.fromDto(dto);
        expect(err.kind, isA<OnramperErrorKind>());
      }
    });

    test('all kinds have complete mappings (counts match)', () {
      expect(
          OnramperErrorKind.values.length, OnramperErrorKindDto.values.length);
    });

    test('is an Exception', () {
      const err = OnramperError(
        kind: OnramperErrorKind.networkError,
        message: 'm',
        recoverable: false,
      );
      expect(err, isA<Exception>());
    });

    test('toString contains kind and message', () {
      const err = OnramperError(
        kind: OnramperErrorKind.amountOutOfRange,
        message: 'amount too low',
        recoverable: true,
      );
      final s = err.toString();
      expect(s, contains('amountOutOfRange'));
      expect(s, contains('amount too low'));
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter_example/utils/format.dart';

void main() {
  test('formatAmount: 2 decimals ≥ 1, 6 below, "0" for zero', () {
    expect(formatAmount(100), '100.00');
    expect(formatAmount(0.0001234), '0.000123');
    expect(formatAmount(0), '0');
  });

  test('plainNumber drops a trailing .0', () {
    expect(plainNumber(100), '100');
    expect(plainNumber(12.5), '12.5');
  });

  test('describeError prefers userMessage and uses the kind as code', () {
    const e = OnramperError(
      kind: OnramperErrorKind.amountOutOfRange,
      message: 'raw',
      recoverable: true,
      userMessage: 'Amount too low',
    );
    expect(describeError(e), (code: 'amountOutOfRange', message: 'Amount too low'));
  });

  test('describeError reads messages from Dart exceptions', () {
    expect(describeError(const FormatException('bad')).message, 'bad');
    expect(describeError(const HttpException('down')).message, 'down');
    expect(describeError(StateError('nope')).message, 'nope');
    expect(describeError(42), (code: 'unknown', message: '42'));
  });
}

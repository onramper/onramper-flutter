import 'dart:io';

import 'package:onramper_flutter/onramper_flutter.dart';

/// 2 decimals at or above 1, 6 below (small crypto payouts), "0" for zero.
String formatAmount(double value) {
  final magnitude = value.abs();
  if (magnitude >= 1) return value.toStringAsFixed(2);
  if (magnitude > 0) return value.toStringAsFixed(6);
  return '0';
}

/// `100.0` → `100`, as JS prints numbers in RN's log lines.
String plainNumber(double value) =>
    value == value.truncateToDouble() ? value.toInt().toString() : '$value';

/// RN `describeError`: code + the user-facing message when there is one.
({String code, String message}) describeError(Object error) => switch (error) {
      OnramperError e => (
          code: e.kind.name,
          message: '${e.userMessage}\nError code: ${e.supportCode}',
        ),
      FormatException e => (code: 'unknown', message: e.message),
      HttpException e => (code: 'unknown', message: e.message),
      StateError e => (code: 'unknown', message: e.message),
      _ => (code: 'unknown', message: '$error'),
    };

import '../platform/pigeon.g.dart';
import 'configuration.dart';

/// Receives SDK log records at or above `OnramperConfiguration.logLevel`.
/// Called on the platform (UI) isolate; keep it fast. Exceptions are reported
/// via `FlutterError.reportError` and never interrupt checkout.
typedef OnramperLogHandler = void Function(OnramperLogRecord record);

/// Structured, sanitized SDK log record. URLs are reduced to hosts, HTTP paths
/// to route templates, and values resembling emails, phone numbers, card
/// numbers or tokens are redacted. Provider messages get best-effort redaction
/// only, so treat exported logs as potentially containing personal data.
class OnramperLogRecord {
  const OnramperLogRecord({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.event,
    required this.context,
    required this.message,
  });

  factory OnramperLogRecord.fromDto(LogRecordDto dto) => OnramperLogRecord(
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(dto.timestampMs, isUtc: true),
        level: switch (dto.level) {
          LogLevelDto.off => OnramperLogLevel.off,
          LogLevelDto.error => OnramperLogLevel.error,
          LogLevelDto.warning => OnramperLogLevel.warning,
          LogLevelDto.info => OnramperLogLevel.info,
          LogLevelDto.debug => OnramperLogLevel.debug,
          LogLevelDto.trace => OnramperLogLevel.trace,
        },
        category: dto.category,
        event: dto.event,
        context: Map.unmodifiable(dto.context),
        message: dto.message,
      );

  /// UTC time the record was emitted.
  final DateTime timestamp;
  final OnramperLogLevel level;

  /// Stable category, e.g. `Checkout`, `ProviderEvents`.
  final String category;

  /// Stable event name, e.g. `checkout.finalized`.
  final String event;
  final Map<String, String> context;

  /// `"<event> k1=v1 k2=v2"`, keys sorted.
  final String message;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/src/models/configuration.dart';
import 'package:onramper_flutter/src/platform/pigeon.g.dart';

void main() {
  group('OnramperConfiguration', () {
    test('toDto round-trips all fields', () {
      const config = OnramperConfiguration(
        apiKey: 'pk_test_123',
        clientId: 'client-abc',
        environment: OnramperEnvironment.development,
        theme: OnramperTheme.dark,
        logLevel: OnramperLogLevel.debug,
      );

      final dto = config.toDto();

      expect(dto.apiKey, 'pk_test_123');
      expect(dto.clientId, 'client-abc');
      expect(dto.environment, EnvironmentDto.development);
      expect(dto.theme, ThemeDto.dark);
      expect(dto.logLevel, LogLevelDto.debug);
    });

    test('defaults are applied when not specified', () {
      const config = OnramperConfiguration(
        apiKey: 'pk',
        clientId: 'c',
      );

      expect(config.environment, OnramperEnvironment.production);
      expect(config.theme, OnramperTheme.system);
      expect(config.logLevel, OnramperLogLevel.off);

      final dto = config.toDto();
      expect(dto.environment, EnvironmentDto.production);
      expect(dto.theme, ThemeDto.system);
      expect(dto.logLevel, LogLevelDto.off);
    });

    test('every OnramperEnvironment maps to a non-null EnvironmentDto', () {
      for (final env in OnramperEnvironment.values) {
        final dto = OnramperConfiguration(
          apiKey: 'k',
          clientId: 'c',
          environment: env,
        ).toDto();
        expect(dto.environment, isA<EnvironmentDto>());
      }
    });

    test('every OnramperTheme maps to a non-null ThemeDto', () {
      for (final theme in OnramperTheme.values) {
        final dto = OnramperConfiguration(
          apiKey: 'k',
          clientId: 'c',
          theme: theme,
        ).toDto();
        expect(dto.theme, isA<ThemeDto>());
      }
    });

    test('every OnramperLogLevel maps to a non-null LogLevelDto', () {
      for (final level in OnramperLogLevel.values) {
        final dto = OnramperConfiguration(
          apiKey: 'k',
          clientId: 'c',
          logLevel: level,
        ).toDto();
        expect(dto.logLevel, isA<LogLevelDto>());
      }
    });

    test('all enums have complete mappings (counts match)', () {
      expect(OnramperEnvironment.values.length, EnvironmentDto.values.length);
      expect(OnramperTheme.values.length, ThemeDto.values.length);
      expect(OnramperLogLevel.values.length, LogLevelDto.values.length);
    });
  });

  test('toDto carries logging flags and hasLogHandler', () {
    final dto = OnramperConfiguration(
      apiKey: 'pk',
      clientId: 'c',
      logHandler: (_) {},
      isEventLoggingEnabled: true,
      isEventConsoleLoggingEnabled: true,
    ).toDto();
    expect(dto.hasLogHandler, isTrue);
    expect(dto.isEventLoggingEnabled, isTrue);
    expect(dto.isEventConsoleLoggingEnabled, isTrue);

    final plain =
        const OnramperConfiguration(apiKey: 'pk', clientId: 'c').toDto();
    expect(plain.hasLogHandler, isFalse);
    expect(plain.isEventLoggingEnabled, isFalse);
    expect(plain.isEventConsoleLoggingEnabled, isFalse);
  });
}

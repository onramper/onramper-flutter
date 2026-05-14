import '../platform/pigeon.g.dart';

/// Session credentials returned by the partner backend, used to bootstrap and
/// later refresh an SDK session.
///
/// Returned by [SessionExpirationHandler] when the native SDK requests a fresh
/// session, and passed to [OnramperClient.initialize] for the initial handshake.
class SessionCredentials {
  const SessionCredentials({
    required this.sessionId,
    required this.sessionToken,
  });

  final String sessionId;
  final String sessionToken;
}

/// Runtime environment the SDK targets.
enum OnramperEnvironment { development, production }

/// Visual theme applied to native checkout UI.
enum OnramperTheme { system, light, dark }

/// Verbosity level for SDK logging.
enum OnramperLogLevel { off, error, warning, info, debug, trace }

/// Configuration passed to [OnramperClient.configure].
///
/// Mirrors the iOS `OnramperConfiguration` and is convertible to a
/// Pigeon [ConfigurationDto] via [toDto].
class OnramperConfiguration {
  const OnramperConfiguration({
    required this.apiKey,
    required this.clientId,
    this.environment = OnramperEnvironment.production,
    this.theme = OnramperTheme.system,
    this.logLevel = OnramperLogLevel.off,
  });

  final String apiKey;
  final String clientId;
  final OnramperEnvironment environment;
  final OnramperTheme theme;
  final OnramperLogLevel logLevel;

  ConfigurationDto toDto() => ConfigurationDto(
        apiKey: apiKey,
        clientId: clientId,
        environment: switch (environment) {
          OnramperEnvironment.development => EnvironmentDto.development,
          OnramperEnvironment.production => EnvironmentDto.production,
        },
        theme: switch (theme) {
          OnramperTheme.system => ThemeDto.system,
          OnramperTheme.light => ThemeDto.light,
          OnramperTheme.dark => ThemeDto.dark,
        },
        logLevel: switch (logLevel) {
          OnramperLogLevel.off => LogLevelDto.off,
          OnramperLogLevel.error => LogLevelDto.error,
          OnramperLogLevel.warning => LogLevelDto.warning,
          OnramperLogLevel.info => LogLevelDto.info,
          OnramperLogLevel.debug => LogLevelDto.debug,
          OnramperLogLevel.trace => LogLevelDto.trace,
        },
      );
}

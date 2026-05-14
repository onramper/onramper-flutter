import Foundation
import OnramperSDK

enum BridgeMappers {
    static func toNative(
        _ dto: ConfigurationDto,
        sessionExpirationHandler: @escaping @Sendable () async throws -> SessionCredentials
    ) -> OnramperConfiguration {
        OnramperConfiguration(
            apiKey: dto.apiKey,
            clientId: dto.clientId,
            environment: toNative(dto.environment),
            theme: toNative(dto.theme),
            logLevel: toNative(dto.logLevel),
            sessionExpirationHandler: sessionExpirationHandler
        )
    }

    static func toNative(_ dto: EnvironmentDto) -> OnramperConfiguration.Environment {
        switch dto {
        case .development: return .development
        case .production:  return .production
        }
    }

    static func toNative(_ dto: ThemeDto) -> OnramperConfiguration.Theme {
        switch dto {
        case .system: return .system
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// Maps `LogLevelDto` to the native `LogLevel`.
    ///
    /// The Pigeon contract declares six levels (`off/error/warning/info/debug/trace`)
    /// to align with common Flutter logging vocabularies. The native SDK currently
    /// exposes only four (`off/error/info/debug`). The two extra DTO cases are
    /// aliased to the closest available native level:
    ///   - `warning` collapses to `error` (next-most-severe level the SDK emits).
    ///   - `trace` collapses to `debug` (most-verbose level the SDK supports).
    ///
    /// If/when the native SDK adds explicit `warning`/`trace` cases, update this
    /// mapping to a 1:1 correspondence.
    static func toNative(_ dto: LogLevelDto) -> LogLevel {
        switch dto {
        case .off:     return .off
        case .error:   return .error
        case .warning: return .error
        case .info:    return .info
        case .debug:   return .debug
        case .trace:   return .debug
        }
    }
}

import Foundation
import OnramperSDK
import SwiftUI

enum BridgeMappers {
    static func toNative(
        _ dto: ConfigurationDto,
        logHandler: OnramperLogHandler?,
        sessionExpirationHandler: @escaping @Sendable () async throws -> SessionCredentials
    ) -> OnramperConfiguration {
        OnramperConfiguration(
            apiKey: dto.apiKey,
            clientId: dto.clientId,
            environment: toNative(dto.environment),
            theme: toNative(dto.theme),
            logLevel: toNative(dto.logLevel),
            logHandler: logHandler,
            isEventLoggingEnabled: dto.isEventLoggingEnabled,
            isEventConsoleLoggingEnabled: dto.isEventConsoleLoggingEnabled,
            sessionExpirationHandler: sessionExpirationHandler
        )
    }

    static func toNative(_ dto: EnvironmentDto) -> OnramperConfiguration.Environment {
        switch dto {
        case .development: return .development
        case .production:  return .production
        }
    }

    /// Color scheme forced on the embedded checkout button so its text
    /// matches the configured theme even when the device appearance differs
    /// (e.g. a light app on a dark-mode phone). `nil` follows the device.
    static func buttonColorScheme(for dto: ThemeDto) -> ColorScheme? {
        switch dto {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
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

    // MARK: - Logging (Swift -> Dart)

    static func fromNative(_ native: LogLevel) -> LogLevelDto {
        switch native {
        case .off:   return .off
        case .error: return .error
        case .info:  return .info
        case .debug: return .debug
        @unknown default: return .debug
        }
    }

    static func fromNative(_ native: OnramperLogRecord) -> LogRecordDto {
        LogRecordDto(
            timestampMs: Int64((native.timestamp.timeIntervalSince1970 * 1000).rounded()),
            level: fromNative(native.level),
            category: native.category,
            event: native.event,
            context: native.context,
            message: native.message
        )
    }

    // MARK: - Quote (Swift -> Dart)

    static func fromNative(_ native: QuoteResponse) -> QuoteDto {
        QuoteDto(
            quoteId: native.quoteId,
            ramp: native.ramp,
            rate: native.rate,
            networkFee: native.networkFee,
            transactionFee: native.transactionFee,
            payout: native.payout,
            paymentMethod: native.paymentMethod,
            recommendations: native.recommendations,
            providerContext: native.providerContext?.mapValues { jsonObject($0) }
        )
    }

    /// Converts a provider JSON value into standard-codec values. `.null`
    /// becomes NSNull so it survives inside collections.
    static func jsonObject(_ value: ProviderJSONValue) -> Any {
        switch value {
        case .string(let s): return s
        case .number(let d): return d
        case .bool(let b):   return b
        case .null:          return NSNull()
        case .array(let a):  return a.map { jsonObject($0) }
        case .object(let o): return o.mapValues { jsonObject($0) }
        @unknown default:    return NSNull()
        }
    }

    // MARK: - CheckoutIntentRequest inputs (Dart -> Swift)

    static func toNative(_ dto: CheckoutIntentRequestDto) -> CheckoutIntentRequest {
        CheckoutIntentRequest(
            onramperTransactionData: toNative(dto.transactionData),
            onlyOnramps: dto.onlyOnramps
        )
    }

    static func toNative(_ dto: UserPrefillDto?) -> OnramperUserPrefill? {
        guard let dto else { return nil }
        return OnramperUserPrefill(
            email: dto.email,
            firstName: dto.firstName,
            lastName: dto.lastName,
            phoneNumber: dto.phoneNumber
        )
    }

    static func toNative(_ dto: OnramperTransactionDataDto) -> OnramperTransactionData {
        OnramperTransactionData(
            source: dto.source,
            destination: dto.destination,
            amount: dto.amount,
            type: toNative(dto.type),
            country: dto.country,
            subdivision: dto.subdivision,
            paymentMethod: dto.paymentMethod,
            wallet: toNative(dto.wallet)
        )
    }

    static func toNative(_ dto: WalletInfoDto) -> WalletInfo {
        WalletInfo(network: dto.network, address: dto.address, memo: dto.memo)
    }

    static func toNative(_ dto: TransactionTypeDto) -> TransactionType {
        switch dto {
        case .buy:  return .buy
        case .sell: return .sell
        }
    }

    // MARK: - Checkout Requirements (Swift -> Dart)

    static func fromNative(_ native: CheckoutRequirement) -> CheckoutRequirementDto {
        switch native {
        case .tos(let r):
            return CheckoutRequirementDto(type: .tos, tos: fromNative(r))
        case .amountLimit(let r):
            return CheckoutRequirementDto(type: .amountLimit, amountLimit: fromNative(r))
        case .userInfo(let r):
            return CheckoutRequirementDto(type: .userInfo, userInfo: fromNative(r))
        case .reverification(let r):
            return CheckoutRequirementDto(type: .reverification, reverification: fromNative(r))
        @unknown default:
            // A newer SDK snapshot introduced a case we can't map. Represent it
            // as `tos` with an empty items list so the state machine can still
            // proceed to `readyToCheckout`; consumers observing this shape
            // should treat it as "unknown requirement, upgrade the plugin".
            return CheckoutRequirementDto(
                type: .tos,
                tos: TosRequirementDto(providerId: "unknown", items: [])
            )
        }
    }

    static func fromNative(_ native: ToSRequirement) -> TosRequirementDto {
        TosRequirementDto(
            providerId: native.providerId,
            items: native.items.map(fromNative)
        )
    }

    static func fromNative(_ native: ToSItem) -> TosItemDto {
        TosItemDto(
            type: fromNative(native.type),
            required: native.required,
            satisfied: native.satisfied,
            url: native.url,
            content: native.content
        )
    }

    static func fromNative(_ native: ToSItemType) -> TosItemTypeDto {
        switch native {
        case .tos:           return .tos
        case .privacyPolicy: return .privacyPolicy
        case .userAgreement: return .userAgreement
        @unknown default:    return .tos
        }
    }

    static func fromNative(_ native: AmountLimitRequirement) -> AmountLimitRequirementDto {
        AmountLimitRequirementDto(
            providerId: native.providerId,
            amountLimitSatisfied: native.amountLimitSatisfied,
            minAmountLimit: native.minAmountLimit,
            maxAmountLimit: native.maxAmountLimit
        )
    }

    static func fromNative(_ native: UserInfoRequirement) -> UserInfoRequirementDto {
        UserInfoRequirementDto(
            providerId: native.providerId,
            fields: native.fields.map(fromNative)
        )
    }

    static func fromNative(_ native: UserInfoField) -> UserInfoFieldDto {
        UserInfoFieldDto(
            type: fromNative(native.type),
            required: native.required,
            satisfied: native.satisfied
        )
    }

    static func fromNative(_ native: UserInfoFieldType) -> UserInfoFieldTypeDto {
        switch native {
        case .firstName:         return .firstName
        case .lastName:          return .lastName
        case .email:             return .email
        case .emailVerification: return .emailVerification
        case .phoneNumber:       return .phoneNumber
        case .phoneVerification: return .phoneVerification
        case .ssnLastFour:       return .ssnLastFour
        case .address:           return .address
        @unknown default:        return .firstName
        }
    }

    static func fromNative(_ native: ReverificationRequirement) -> ReverificationRequirementDto {
        ReverificationRequirementDto(
            providerId: native.providerId,
            field: fromNative(native.field),
            requiredRecencyDays: Int64(native.requiredRecencyDays),
            lastVerifiedAt: native.lastVerifiedAt
        )
    }

    static func fromNative(_ native: ReverificationField) -> ReverificationFieldDto {
        switch native {
        case .email:      return .email
        case .phone:      return .phone
        @unknown default: return .email
        }
    }

    static func fromNative(_ native: CheckoutRequirementType) -> CheckoutRequirementTypeDto {
        switch native {
        case .tos:            return .tos
        case .amountLimit:    return .amountLimit
        case .userInfo:       return .userInfo
        case .reverification: return .reverification
        @unknown default:     return .tos
        }
    }

    static func toNative(_ dto: CheckoutRequirementTypeDto) -> CheckoutRequirementType {
        switch dto {
        case .tos:            return .tos
        case .amountLimit:    return .amountLimit
        case .userInfo:       return .userInfo
        case .reverification: return .reverification
        }
    }

    // MARK: - OnramperState (Swift -> Dart)

    static func fromNative(_ native: OnramperState) -> OnramperStateDto {
        switch native {
        case .idle:
            return OnramperStateDto(kind: .idle)
        case .initializing:
            return OnramperStateDto(kind: .initializing)
        case .ready:
            return OnramperStateDto(kind: .ready)
        case .checkoutPreparing:
            return OnramperStateDto(kind: .checkoutPreparing)
        case .requireLogin(let reqs):
            return OnramperStateDto(
                kind: .requireLogin,
                requireLoginRequirements: reqs.map(fromNative)
            )
        case .authenticating:
            return OnramperStateDto(kind: .authenticating)
        case .readyToCheckout:
            return OnramperStateDto(kind: .readyToCheckout)
        case .finalizing:
            return OnramperStateDto(kind: .finalizing)
        case .rendering(let ctx):
            return OnramperStateDto(
                kind: .rendering,
                renderContext: fromNative(ctx)
            )
        case .paymentPending:
            return OnramperStateDto(kind: .paymentPending)
        case .completed:
            return OnramperStateDto(kind: .completed)
        case .failed(let err):
            return OnramperStateDto(
                kind: .failed,
                failedError: fromNative(err)
            )
        @unknown default:
            return OnramperStateDto(kind: .idle)
        }
    }

    static func fromNative(_ native: OnramperState.RenderContext) -> RenderContextDto {
        RenderContextDto(
            url: native.url.absoluteString,
            renderType: fromNative(native.renderType),
            paymentType: fromNative(native.paymentType)
        )
    }

    static func fromNative(_ native: RenderType) -> RenderTypeDto {
        switch native {
        case .webview:    return .webview
        case .deeplink:   return .deeplink
        @unknown default: return .webview
        }
    }

    static func fromNative(_ native: CheckoutPaymentType) -> CheckoutPaymentTypeDto {
        switch native {
        case .applePay:   return .applePay
        case .revolutPay: return .revolutPay
        @unknown default: return .applePay
        }
    }

    // MARK: - CheckoutFinalizeResponse

    static func fromNative(_ native: CheckoutFinalizeResponse) -> CheckoutFinalizeResponseDto {
        CheckoutFinalizeResponseDto(
            headlessCheckoutId: native.headlessCheckoutId,
            onramperTransactionId: native.onramperTransactionId,
            headlessCheckoutData: fromNative(native.headlessCheckoutData)
        )
    }

    static func fromNative(_ native: HeadlessCheckoutData) -> HeadlessCheckoutDataDto {
        HeadlessCheckoutDataDto(
            url: native.url,
            renderType: fromNative(native.renderType),
            checkoutPaymentType: fromNative(native.checkoutPaymentType)
        )
    }

    // MARK: - CheckoutEvent (Swift -> Dart)

    /// Maps every native `CheckoutEvent` case to a Pigeon DTO. Callers always
    /// forward the result — there are no dropped events.
    static func fromNative(_ native: CheckoutEvent) -> CheckoutEventDto {
        switch native {
        case .stateChanged(let state):
            return CheckoutEventDto(kind: .stateChanged, state: fromNative(state))
        case .checkoutStarted(let id):
            return CheckoutEventDto(kind: .checkoutStarted, checkoutId: id)
        case .loginRequired(let reqs):
            return CheckoutEventDto(
                kind: .loginRequired,
                loginRequirements: reqs.map(fromNative)
            )
        case .readyToCheckout:
            return CheckoutEventDto(kind: .readyToCheckout)
        case .requirementSatisfied(let type):
            return CheckoutEventDto(kind: .requirementSatisfied, requirementType: fromNative(type))
        case .checkoutFinalized(let response):
            let dtoResponse = fromNative(response)
            // Also populate `renderContext` (without paymentType, since this
            // event's HeadlessCheckoutData carries a String url that becomes
            // available on the .rendering state anyway).
            let renderCtx = RenderContextDto(
                url: response.headlessCheckoutData.url,
                renderType: fromNative(response.headlessCheckoutData.renderType),
                paymentType: fromNative(response.headlessCheckoutData.checkoutPaymentType)
            )
            return CheckoutEventDto(
                kind: .checkoutFinalized,
                checkoutId: response.headlessCheckoutId,
                renderContext: renderCtx,
                finalizeResponse: dtoResponse
            )
        case .renderingStarted(let url, let renderType):
            // The native `renderingStarted` event carries only url + renderType.
            // The payment type is not part of this event's payload — it can be
            // read off `state.rendering.paymentType` if needed.
            let renderCtx = RenderContextDto(
                url: url.absoluteString,
                renderType: fromNative(renderType),
                paymentType: nil
            )
            return CheckoutEventDto(kind: .renderingStarted, renderContext: renderCtx)
        case .completed(let checkoutId):
            return CheckoutEventDto(kind: .completed, checkoutId: checkoutId)
        case .failed(let err):
            return CheckoutEventDto(kind: .failed, error: fromNative(err))
        case .checkoutCancelled:
            return CheckoutEventDto(kind: .checkoutCancelled)
        case .providerReady:
            return CheckoutEventDto(kind: .providerReady)
        case .paymentAuthorized:
            return CheckoutEventDto(kind: .paymentAuthorized)
        case .paymentProcessing:
            return CheckoutEventDto(kind: .paymentProcessing)
        case .paymentCancelled:
            return CheckoutEventDto(kind: .paymentCancelled)
        case .providerError(let reason):
            return CheckoutEventDto(kind: .providerError, providerReason: reason)
        case .paymentPending:
            return CheckoutEventDto(kind: .paymentPending)
        case .challengeStarted:
            return CheckoutEventDto(kind: .challengeStarted)
        case .challengeCompleted:
            return CheckoutEventDto(kind: .challengeCompleted)
        case .customerOnboardingRequired:
            return CheckoutEventDto(kind: .customerOnboardingRequired)
        @unknown default:
            // Unknown provider-lifecycle events map to `providerError` with a
            // generic reason so consumers still get some signal.
            return CheckoutEventDto(
                kind: .providerError,
                providerReason: "Unknown checkout event"
            )
        }
    }

    // MARK: - Button style (Dart -> Swift)

    /// Parses a hex color string like `#RRGGBB` or `#RRGGBBAA` into a SwiftUI
    /// `Color`. Returns `nil` on parse failure so the caller can fall back to
    /// the SDK's default.
    static func parseHexColor(_ hex: String) -> Color? {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6 || trimmed.count == 8,
              let value = UInt64(trimmed, radix: 16) else {
            return nil
        }
        let hasAlpha = trimmed.count == 8
        let r = Double((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255.0
        let g = Double((value >> (hasAlpha ?  16 :  8)) & 0xFF) / 255.0
        let b = Double((value >> (hasAlpha ?   8 :  0)) & 0xFF) / 255.0
        let a = hasAlpha ? Double(value & 0xFF) / 255.0 : 1.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    static func toNative(_ dto: CheckoutButtonStyleDto?) -> CheckoutButtonStyle {
        let defaults = CheckoutButtonStyle()
        guard let dto else { return defaults }
        return CheckoutButtonStyle(
            backgroundColor: dto.backgroundColor.flatMap(parseHexColor) ?? defaults.backgroundColor,
            foregroundColor: dto.foregroundColor.flatMap(parseHexColor) ?? defaults.foregroundColor,
            borderRadius: dto.borderRadius.map { CGFloat($0) } ?? defaults.borderRadius
        )
    }

    // MARK: - OnramperError (Swift -> Dart)

    static func fromNative(_ native: OnramperError) -> OnramperErrorDto {
        let message = native.errorDescription ?? "Unknown error"
        let userMessage = native.userMessage
        let supportCode = native.supportCode
        switch native {
        case .notInitialized:
            return OnramperErrorDto(kind: .notInitialized, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false)
        case .initializationFailed(let s):
            return OnramperErrorDto(kind: .initializationFailed, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, debugInfo: s)
        case .attestationFailed(let s):
            return OnramperErrorDto(kind: .attestationFailed, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, debugInfo: s)
        case .invalidStateTransition(let from, let to):
            return OnramperErrorDto(kind: .invalidStateTransition, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, fromState: from, toState: to)
        case .invalidState(let expected, let actual):
            return OnramperErrorDto(kind: .invalidState, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, expectedState: expected, actualState: actual)
        case .networkError(let code, let m):
            return OnramperErrorDto(kind: .networkError, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: true, code: Int64(code), debugInfo: m)
        case .decodingError(let s):
            return OnramperErrorDto(kind: .decodingError, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, debugInfo: s)
        case .timeout:
            return OnramperErrorDto(kind: .timeout, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: true)
        case .requirementNotSatisfied(let s):
            return OnramperErrorDto(kind: .requirementNotSatisfied, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: true, debugInfo: s)
        case .amountOutOfRange(let min, let max):
            return OnramperErrorDto(kind: .amountOutOfRange, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: true, minAmount: min, maxAmount: max)
        case .oidcFlowCancelled:
            return OnramperErrorDto(kind: .oidcFlowCancelled, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: true)
        case .oidcTokenExchangeFailed(let s):
            return OnramperErrorDto(kind: .oidcTokenExchangeFailed, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, debugInfo: s)
        case .oidcFlowFailed(let s):
            return OnramperErrorDto(kind: .oidcFlowFailed, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, debugInfo: s)
        case .userTokenInvalid:
            return OnramperErrorDto(kind: .userTokenInvalid, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: true)
        case .userTokenRefreshFailed(let s):
            return OnramperErrorDto(kind: .userTokenRefreshFailed, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: true, debugInfo: s)
        case .webviewLoadFailed(let s):
            return OnramperErrorDto(kind: .webviewLoadFailed, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, debugInfo: s)
        case .deepLinkFailed(let s):
            return OnramperErrorDto(kind: .deepLinkFailed, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, debugInfo: s)
        case .invalidRequest(let field, let debug):
            return OnramperErrorDto(kind: .invalidRequest, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: true, field: field, debugInfo: debug)
        case .quoteUnavailable(let debug):
            return OnramperErrorDto(kind: .quoteUnavailable, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: true, debugInfo: debug)
        case .checkoutForbidden(let debug):
            return OnramperErrorDto(kind: .checkoutForbidden, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, debugInfo: debug)
        case .temporaryFailure(let retry, let debug):
            return OnramperErrorDto(kind: .temporaryFailure, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: true, retryAfterSeconds: retry, debugInfo: debug)
        case .unrecoverable(let debug):
            return OnramperErrorDto(kind: .unrecoverable, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, debugInfo: debug)
        case .configurationError(let reason):
            return OnramperErrorDto(kind: .configurationError, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, debugInfo: reason)
        case .deviceBlocked:
            return OnramperErrorDto(kind: .deviceBlocked, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false)
        case .securityStorageFailed(let status):
            return OnramperErrorDto(kind: .securityStorageFailed, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, code: Int64(status))
        case .securityTrustFailed(let host):
            return OnramperErrorDto(kind: .securityTrustFailed, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, host: host)
        case .paymentFailed(let s):
            return OnramperErrorDto(kind: .paymentFailed, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: true, debugInfo: s)
        case .providerFailed(let s):
            // Outcome unknown — the payment may have gone through. Not recoverable by blind retry.
            return OnramperErrorDto(kind: .providerFailed, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, debugInfo: s)
        case .applePayNotConfigured:
            return OnramperErrorDto(kind: .applePayNotConfigured, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false)
        @unknown default:
            return OnramperErrorDto(kind: .unrecoverable, message: message, userMessage: userMessage, supportCode: supportCode, recoverable: false, debugInfo: "unknown error: \(String(describing: native))")
        }
    }

    // MARK: - Errors crossing the HostApi

    /// Wraps a typed error for a HostApi completion. The Pigeon codec encodes
    /// the DTO in `details`; Dart rethrows it as `OnramperError`.
    static func pigeonError(_ dto: OnramperErrorDto) -> PigeonError {
        PigeonError(code: "onramper_error", message: dto.message, details: dto)
    }

    /// Wrapper-originated: a newer preparation, reset, signOut or dispose
    /// superseded this getCheckoutRequirements call.
    static func intentInvalidatedDto() -> OnramperErrorDto {
        OnramperErrorDto(
            kind: .intentInvalidated,
            message: "This checkout preparation was superseded or cleared. Use the most recent request.",
            userMessage: "Your checkout details have changed. Please use the latest quote.",
            supportCode: "FLUTTER-INTENT-INVALIDATED",
            recoverable: true
        )
    }
}

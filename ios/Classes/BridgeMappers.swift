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
            errors: native.errors?.map(fromNative)
        )
    }

    static func fromNative(_ native: QuoteError) -> QuoteErrorDto {
        QuoteErrorDto(type: native.type, message: native.message)
    }

    // MARK: - CheckoutIntentRequest inputs (Dart -> Swift)

    static func toNative(_ dto: CheckoutIntentRequestDto) -> CheckoutIntentRequest {
        CheckoutIntentRequest(
            onramperTransactionData: toNative(dto.transactionData),
            onlyOnramps: dto.onlyOnramps
        )
    }

    static func toNative(_ dto: OnramperTransactionDataDto) -> OnramperTransactionData {
        // Pass values through unchanged; `OnramperTransactionData.init`
        // lowercases source/destination/country/subdivision itself.
        OnramperTransactionData(
            onramp: dto.onramp,
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

    static func fromNative(_ native: CheckoutIntentResponse) -> CheckoutRequirementsResultDto {
        CheckoutRequirementsResultDto(
            headlessCheckoutId: native.headlessCheckoutId,
            requirements: native.checkoutRequirements.map(fromNative),
            quote: fromNative(native.quote)
        )
    }

    static func fromNative(_ native: CheckoutRequirement) -> CheckoutRequirementDto {
        switch native {
        case .tos(let r):
            return CheckoutRequirementDto(type: .tos, tos: fromNative(r), amountLimit: nil, userInfo: nil)
        case .amountLimit(let r):
            return CheckoutRequirementDto(type: .amountLimit, tos: nil, amountLimit: fromNative(r), userInfo: nil)
        case .userInfo(let r):
            return CheckoutRequirementDto(type: .userInfo, tos: nil, amountLimit: nil, userInfo: fromNative(r))
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
        }
    }

    static func fromNative(_ native: AmountLimitRequirement) -> AmountLimitRequirementDto {
        AmountLimitRequirementDto(
            providerId: native.providerId,
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
        }
    }

    static func fromNative(_ native: CheckoutRequirementType) -> CheckoutRequirementTypeDto {
        switch native {
        case .tos:         return .tos
        case .amountLimit: return .amountLimit
        case .userInfo:    return .userInfo
        }
    }

    static func toNative(_ dto: CheckoutRequirementTypeDto) -> CheckoutRequirementType {
        switch dto {
        case .tos:         return .tos
        case .amountLimit: return .amountLimit
        case .userInfo:    return .userInfo
        }
    }
}

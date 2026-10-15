import XCTest
@testable import onramper_flutter
import OnramperSDK
import SwiftUI

final class BridgeMappersTests: XCTestCase {
    func test_configurationDto_toNative_mapsAllFields() {
        let dto = ConfigurationDto(
            apiKey: "pk_test_x",
            clientId: "01HABCDEF",
            environment: .development,
            theme: .light,
            logLevel: .debug
        )

        let native = BridgeMappers.toNative(dto, sessionExpirationHandler: { fatalError("not invoked in this test") })

        XCTAssertEqual(native.apiKey, "pk_test_x")
        XCTAssertEqual(native.clientId, "01HABCDEF")
        XCTAssertEqual(native.environment, .development)
        XCTAssertEqual(native.theme, .light)
        XCTAssertEqual(native.logLevel, .debug)
    }

    func test_configurationDto_environmentProduction_maps() {
        let dto = ConfigurationDto(
            apiKey: "pk_test_y",
            clientId: "01H",
            environment: .production,
            theme: .system,
            logLevel: .off
        )

        let native = BridgeMappers.toNative(dto, sessionExpirationHandler: { fatalError() })

        XCTAssertEqual(native.environment, .production)
        XCTAssertEqual(native.theme, .system)
        XCTAssertEqual(native.logLevel, .off)
    }

    // MARK: - Quote (Swift -> Dart)

    func test_quoteResponse_fromNative_fullyPopulated_mapsAllFields() {
        let native = QuoteResponse(
            quoteId: "q_123",
            ramp: "moonpay",
            rate: 1.05,
            payout: 100.0,
            paymentMethod: "credit_card",
            networkFee: 0.5,
            transactionFee: 1.25,
            recommendations: ["best_rate", "fastest"]
        )

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.quoteId, "q_123")
        XCTAssertEqual(dto.ramp, "moonpay")
        XCTAssertEqual(dto.rate, 1.05)
        XCTAssertEqual(dto.networkFee, 0.5)
        XCTAssertEqual(dto.transactionFee, 1.25)
        XCTAssertEqual(dto.payout, 100.0)
        XCTAssertEqual(dto.paymentMethod, "credit_card")
        XCTAssertEqual(dto.recommendations, ["best_rate", "fastest"])
    }

    func test_quoteResponse_fromNative_omittedRecommendations_mapsToNil() {
        let native = QuoteResponse(
            quoteId: "q",
            ramp: "r",
            rate: 1,
            payout: 1,
            paymentMethod: "pm",
            networkFee: 0,
            transactionFee: 0
        )

        let dto = BridgeMappers.fromNative(native)

        XCTAssertNil(dto.recommendations)
    }

    // MARK: - CheckoutIntentRequest inputs (Dart -> Swift)

    func test_transactionTypeDto_toNative_buy() {
        XCTAssertEqual(BridgeMappers.toNative(TransactionTypeDto.buy), TransactionType.buy)
    }

    func test_transactionTypeDto_toNative_sell() {
        XCTAssertEqual(BridgeMappers.toNative(TransactionTypeDto.sell), TransactionType.sell)
    }

    func test_walletInfoDto_toNative_allFields() {
        let dto = WalletInfoDto(network: "ethereum", address: "0xabc", memo: "tag-1")

        let native = BridgeMappers.toNative(dto)

        XCTAssertEqual(native.network, "ethereum")
        XCTAssertEqual(native.address, "0xabc")
        XCTAssertEqual(native.memo, "tag-1")
    }

    func test_walletInfoDto_toNative_nilMemo() {
        let dto = WalletInfoDto(network: "bitcoin", address: "bc1q", memo: nil)

        let native = BridgeMappers.toNative(dto)

        XCTAssertNil(native.memo)
    }

    func test_onramperTransactionDataDto_toNative_allFields() {
        let dto = OnramperTransactionDataDto(
            source: "USD",
            destination: "BTC",
            amount: 100.0,
            type: .buy,
            paymentMethod: "credit_card",
            wallet: WalletInfoDto(network: "ethereum", address: "0xabc", memo: nil),
            country: "US",
            subdivision: "US-CA"
        )

        let native = BridgeMappers.toNative(dto)

        // Native init lowercases source/destination/country/subdivision.
        XCTAssertEqual(native.source, "usd")
        XCTAssertEqual(native.destination, "btc")
        XCTAssertEqual(native.amount, 100.0)
        XCTAssertEqual(native.type, .buy)
        XCTAssertEqual(native.country, "us")
        XCTAssertEqual(native.subdivision, "us-ca")
        XCTAssertEqual(native.paymentMethod, "credit_card")
        XCTAssertEqual(native.wallet.network, "ethereum")
        XCTAssertEqual(native.wallet.address, "0xabc")
    }

    func test_onramperTransactionDataDto_toNative_optionalsNil() {
        let dto = OnramperTransactionDataDto(
            source: "usd",
            destination: "btc",
            amount: 1.0,
            type: .sell,
            paymentMethod: "pm",
            wallet: WalletInfoDto(network: "n", address: "a", memo: nil),
            country: nil,
            subdivision: nil
        )

        let native = BridgeMappers.toNative(dto)

        XCTAssertNil(native.country)
        XCTAssertNil(native.subdivision)
        XCTAssertEqual(native.type, .sell)
    }

    func test_checkoutIntentRequestDto_toNative_passesThroughOnlyOnramps() {
        let dto = CheckoutIntentRequestDto(
            transactionData: OnramperTransactionDataDto(
                source: "usd",
                destination: "btc",
                amount: 50.0,
                type: .buy,
                paymentMethod: "pm",
                wallet: WalletInfoDto(network: "ethereum", address: "0x", memo: nil)
            ),
            onlyOnramps: ["moonpay", "transak"]
        )

        let native = BridgeMappers.toNative(dto)

        XCTAssertEqual(native.onlyOnramps, ["moonpay", "transak"])
        XCTAssertEqual(native.onramperTransactionData.amount, 50.0)
    }

    func test_checkoutIntentRequestDto_toNative_nilOnlyOnramps() {
        let dto = CheckoutIntentRequestDto(
            transactionData: OnramperTransactionDataDto(
                source: "usd",
                destination: "btc",
                amount: 1.0,
                type: .buy,
                paymentMethod: "pm",
                wallet: WalletInfoDto(network: "n", address: "a", memo: nil)
            ),
            onlyOnramps: nil
        )

        let native = BridgeMappers.toNative(dto)

        XCTAssertNil(native.onlyOnramps)
    }

    // MARK: - Checkout Requirements (Swift -> Dart)

    func test_checkoutRequirementType_fromNative() {
        XCTAssertEqual(BridgeMappers.fromNative(CheckoutRequirementType.tos), .tos)
        XCTAssertEqual(BridgeMappers.fromNative(CheckoutRequirementType.amountLimit), .amountLimit)
        XCTAssertEqual(BridgeMappers.fromNative(CheckoutRequirementType.userInfo), .userInfo)
        XCTAssertEqual(BridgeMappers.fromNative(CheckoutRequirementType.reverification), .reverification)
    }

    func test_checkoutRequirementType_toNative() {
        XCTAssertEqual(BridgeMappers.toNative(CheckoutRequirementTypeDto.tos), .tos)
        XCTAssertEqual(BridgeMappers.toNative(CheckoutRequirementTypeDto.amountLimit), .amountLimit)
        XCTAssertEqual(BridgeMappers.toNative(CheckoutRequirementTypeDto.userInfo), .userInfo)
        XCTAssertEqual(BridgeMappers.toNative(CheckoutRequirementTypeDto.reverification), .reverification)
    }

    func test_tosItemType_fromNative() {
        XCTAssertEqual(BridgeMappers.fromNative(ToSItemType.tos), .tos)
        XCTAssertEqual(BridgeMappers.fromNative(ToSItemType.privacyPolicy), .privacyPolicy)
        XCTAssertEqual(BridgeMappers.fromNative(ToSItemType.userAgreement), .userAgreement)
    }

    func test_userInfoFieldType_fromNative_allCases() {
        XCTAssertEqual(BridgeMappers.fromNative(UserInfoFieldType.firstName), .firstName)
        XCTAssertEqual(BridgeMappers.fromNative(UserInfoFieldType.lastName), .lastName)
        XCTAssertEqual(BridgeMappers.fromNative(UserInfoFieldType.email), .email)
        XCTAssertEqual(BridgeMappers.fromNative(UserInfoFieldType.emailVerification), .emailVerification)
        XCTAssertEqual(BridgeMappers.fromNative(UserInfoFieldType.phoneNumber), .phoneNumber)
        XCTAssertEqual(BridgeMappers.fromNative(UserInfoFieldType.phoneVerification), .phoneVerification)
        XCTAssertEqual(BridgeMappers.fromNative(UserInfoFieldType.ssnLastFour), .ssnLastFour)
        XCTAssertEqual(BridgeMappers.fromNative(UserInfoFieldType.address), .address)
    }

    func test_reverificationField_fromNative() {
        XCTAssertEqual(BridgeMappers.fromNative(ReverificationField.email), .email)
        XCTAssertEqual(BridgeMappers.fromNative(ReverificationField.phone), .phone)
    }

    func test_tosItem_fromNative_mapsAllFields() {
        let native = ToSItem(type: .privacyPolicy, required: true, satisfied: false, url: "https://x", content: "blah")

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.type, .privacyPolicy)
        XCTAssertTrue(dto.required)
        XCTAssertFalse(dto.satisfied)
        XCTAssertEqual(dto.url, "https://x")
        XCTAssertEqual(dto.content, "blah")
    }

    func test_tosRequirement_fromNative() {
        let native = ToSRequirement(providerId: "moonpay", items: [
            ToSItem(type: .tos, required: true, satisfied: false, url: nil, content: nil),
        ])

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.providerId, "moonpay")
        XCTAssertEqual(dto.items.count, 1)
        XCTAssertEqual(dto.items[0].type, .tos)
    }

    func test_amountLimitRequirement_fromNative_carriesSatisfiedFlag() {
        let native = AmountLimitRequirement(
            providerId: "moonpay",
            minAmountLimit: 10.0,
            maxAmountLimit: 1000.0,
            amountLimitSatisfied: true
        )

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.providerId, "moonpay")
        XCTAssertEqual(dto.minAmountLimit, 10.0)
        XCTAssertEqual(dto.maxAmountLimit, 1000.0)
        XCTAssertTrue(dto.amountLimitSatisfied)
    }

    func test_amountLimitRequirement_fromNative_unsatisfied() {
        let native = AmountLimitRequirement(
            providerId: "moonpay",
            minAmountLimit: 10.0,
            maxAmountLimit: 1000.0,
            amountLimitSatisfied: false
        )

        let dto = BridgeMappers.fromNative(native)

        XCTAssertFalse(dto.amountLimitSatisfied)
    }

    func test_userInfoRequirement_fromNative() {
        let native = UserInfoRequirement(providerId: "moonpay", fields: [
            UserInfoField(type: .firstName, required: true, satisfied: false),
            UserInfoField(type: .email, required: true, satisfied: true),
        ])

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.providerId, "moonpay")
        XCTAssertEqual(dto.fields.count, 2)
        XCTAssertEqual(dto.fields[0].type, .firstName)
        XCTAssertFalse(dto.fields[0].satisfied)
        XCTAssertEqual(dto.fields[1].type, .email)
        XCTAssertTrue(dto.fields[1].satisfied)
    }

    func test_reverificationRequirement_fromNative_fullyPopulated() {
        let native = ReverificationRequirement(
            providerId: "moonpay",
            field: .phone,
            requiredRecencyDays: 90,
            lastVerifiedAt: "2026-05-01T00:00:00Z"
        )

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.providerId, "moonpay")
        XCTAssertEqual(dto.field, .phone)
        XCTAssertEqual(dto.requiredRecencyDays, 90)
        XCTAssertEqual(dto.lastVerifiedAt, "2026-05-01T00:00:00Z")
    }

    func test_reverificationRequirement_fromNative_nilLastVerifiedAt() {
        let native = ReverificationRequirement(
            providerId: "p",
            field: .email,
            requiredRecencyDays: 30
        )

        let dto = BridgeMappers.fromNative(native)

        XCTAssertNil(dto.lastVerifiedAt)
    }

    func test_checkoutRequirement_fromNative_tos_populatesOnlyTos() {
        let native = CheckoutRequirement.tos(ToSRequirement(providerId: "p", items: []))

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.type, .tos)
        XCTAssertNotNil(dto.tos)
        XCTAssertNil(dto.amountLimit)
        XCTAssertNil(dto.userInfo)
        XCTAssertNil(dto.reverification)
    }

    func test_checkoutRequirement_fromNative_amountLimit_populatesOnlyAmount() {
        let native = CheckoutRequirement.amountLimit(AmountLimitRequirement(providerId: "p", amountLimitSatisfied: false))

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.type, .amountLimit)
        XCTAssertNil(dto.tos)
        XCTAssertNotNil(dto.amountLimit)
        XCTAssertNil(dto.userInfo)
        XCTAssertNil(dto.reverification)
    }

    func test_checkoutRequirement_fromNative_userInfo_populatesOnlyUserInfo() {
        let native = CheckoutRequirement.userInfo(UserInfoRequirement(providerId: "p", fields: []))

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.type, .userInfo)
        XCTAssertNil(dto.tos)
        XCTAssertNil(dto.amountLimit)
        XCTAssertNotNil(dto.userInfo)
        XCTAssertNil(dto.reverification)
    }

    func test_checkoutRequirement_fromNative_reverification_populatesOnlyReverification() {
        let native = CheckoutRequirement.reverification(
            ReverificationRequirement(providerId: "p", field: .phone, requiredRecencyDays: 30)
        )

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.type, .reverification)
        XCTAssertNil(dto.tos)
        XCTAssertNil(dto.amountLimit)
        XCTAssertNil(dto.userInfo)
        XCTAssertNotNil(dto.reverification)
        XCTAssertEqual(dto.reverification?.field, .phone)
    }

    // MARK: - OnramperState (Swift -> Dart)

    func test_renderType_fromNative() {
        XCTAssertEqual(BridgeMappers.fromNative(RenderType.webview), .webview)
        XCTAssertEqual(BridgeMappers.fromNative(RenderType.deeplink), .deeplink)
    }

    func test_checkoutPaymentType_fromNative() {
        XCTAssertEqual(BridgeMappers.fromNative(CheckoutPaymentType.applePay), .applePay)
        XCTAssertEqual(BridgeMappers.fromNative(CheckoutPaymentType.revolutPay), .revolutPay)
    }

    func test_renderContext_fromNative_mapsAllFields() {
        let native = OnramperState.RenderContext(
            url: URL(string: "https://checkout.example.com/abc")!,
            renderType: .webview,
            paymentType: .applePay
        )

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.url, "https://checkout.example.com/abc")
        XCTAssertEqual(dto.renderType, .webview)
        XCTAssertEqual(dto.paymentType, .applePay)
    }

    func test_onramperState_fromNative_idle() {
        let dto = BridgeMappers.fromNative(OnramperState.idle)
        XCTAssertEqual(dto.kind, .idle)
        XCTAssertNil(dto.requireLoginRequirements)
        XCTAssertNil(dto.renderContext)
        XCTAssertNil(dto.failedError)
    }

    func test_onramperState_fromNative_initializing() {
        XCTAssertEqual(BridgeMappers.fromNative(OnramperState.initializing).kind, .initializing)
    }

    func test_onramperState_fromNative_ready() {
        XCTAssertEqual(BridgeMappers.fromNative(OnramperState.ready).kind, .ready)
    }

    func test_onramperState_fromNative_checkoutPreparing() {
        XCTAssertEqual(BridgeMappers.fromNative(OnramperState.checkoutPreparing).kind, .checkoutPreparing)
    }

    func test_onramperState_fromNative_authenticating() {
        XCTAssertEqual(BridgeMappers.fromNative(OnramperState.authenticating).kind, .authenticating)
    }

    func test_onramperState_fromNative_readyToCheckout() {
        XCTAssertEqual(BridgeMappers.fromNative(OnramperState.readyToCheckout).kind, .readyToCheckout)
    }

    func test_onramperState_fromNative_finalizing() {
        XCTAssertEqual(BridgeMappers.fromNative(OnramperState.finalizing).kind, .finalizing)
    }

    func test_onramperState_fromNative_completed() {
        XCTAssertEqual(BridgeMappers.fromNative(OnramperState.completed).kind, .completed)
    }

    func test_onramperState_fromNative_requireLogin_populatesRequirements() {
        let reqs: [CheckoutRequirement] = [
            .tos(ToSRequirement(providerId: "p", items: [])),
            .userInfo(UserInfoRequirement(providerId: "p", fields: [])),
        ]

        let dto = BridgeMappers.fromNative(OnramperState.requireLogin(reqs))

        XCTAssertEqual(dto.kind, .requireLogin)
        XCTAssertEqual(dto.requireLoginRequirements?.count, 2)
        XCTAssertNil(dto.renderContext)
        XCTAssertNil(dto.failedError)
    }

    func test_onramperState_fromNative_rendering_populatesRenderContext() {
        let ctx = OnramperState.RenderContext(
            url: URL(string: "https://x.example.com")!,
            renderType: .deeplink,
            paymentType: .revolutPay
        )

        let dto = BridgeMappers.fromNative(OnramperState.rendering(ctx))

        XCTAssertEqual(dto.kind, .rendering)
        XCTAssertNil(dto.requireLoginRequirements)
        XCTAssertEqual(dto.renderContext?.url, "https://x.example.com")
        XCTAssertEqual(dto.renderContext?.renderType, .deeplink)
        XCTAssertEqual(dto.renderContext?.paymentType, .revolutPay)
        XCTAssertNil(dto.failedError)
    }

    func test_onramperState_fromNative_failed_populatesFailedError() {
        let dto = BridgeMappers.fromNative(OnramperState.failed(.timeout))

        XCTAssertEqual(dto.kind, .failed)
        XCTAssertNil(dto.requireLoginRequirements)
        XCTAssertNil(dto.renderContext)
        XCTAssertEqual(dto.failedError?.kind, .timeout)
    }

    // MARK: - CheckoutFinalizeResponse

    func test_checkoutFinalizeResponse_fromNative_mapsAllFields() {
        let native = CheckoutFinalizeResponse(
            headlessCheckoutId: "co_1",
            onramperTransactionId: "01JTXN0000000000000000000",
            headlessCheckoutData: HeadlessCheckoutData(
                checkoutPaymentType: .applePay,
                url: "https://pay.example.com/co_1",
                renderType: .webview
            )
        )

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.headlessCheckoutId, "co_1")
        XCTAssertEqual(dto.headlessCheckoutData.url, "https://pay.example.com/co_1")
        XCTAssertEqual(dto.headlessCheckoutData.renderType, .webview)
        XCTAssertEqual(dto.headlessCheckoutData.checkoutPaymentType, .applePay)
    }

    // MARK: - CheckoutEvent (Swift -> Dart)

    func test_checkoutEvent_fromNative_stateChanged() {
        let dto = BridgeMappers.fromNative(CheckoutEvent.stateChanged(.ready))

        XCTAssertEqual(dto.kind, .stateChanged)
        XCTAssertEqual(dto.state?.kind, .ready)
        XCTAssertNil(dto.checkoutId)
        XCTAssertNil(dto.loginRequirements)
        XCTAssertNil(dto.requirementType)
        XCTAssertNil(dto.renderContext)
        XCTAssertNil(dto.error)
    }

    func test_checkoutEvent_fromNative_checkoutStarted() {
        let dto = BridgeMappers.fromNative(CheckoutEvent.checkoutStarted("co_abc"))

        XCTAssertEqual(dto.kind, .checkoutStarted)
        XCTAssertEqual(dto.checkoutId, "co_abc")
        XCTAssertNil(dto.state)
    }

    func test_checkoutEvent_fromNative_loginRequired() {
        let reqs: [CheckoutRequirement] = [.userInfo(UserInfoRequirement(providerId: "p", fields: []))]

        let dto = BridgeMappers.fromNative(CheckoutEvent.loginRequired(reqs))

        XCTAssertEqual(dto.kind, .loginRequired)
        XCTAssertEqual(dto.loginRequirements?.count, 1)
        XCTAssertEqual(dto.loginRequirements?[0].type, .userInfo)
    }

    func test_checkoutEvent_fromNative_readyToCheckout() {
        let dto = BridgeMappers.fromNative(CheckoutEvent.readyToCheckout)

        XCTAssertEqual(dto.kind, .readyToCheckout)
        XCTAssertNil(dto.state)
        XCTAssertNil(dto.checkoutId)
    }

    func test_checkoutEvent_fromNative_requirementSatisfied() {
        let dto = BridgeMappers.fromNative(CheckoutEvent.requirementSatisfied(.amountLimit))

        XCTAssertEqual(dto.kind, .requirementSatisfied)
        XCTAssertEqual(dto.requirementType, .amountLimit)
    }

    func test_checkoutEvent_fromNative_checkoutFinalized_populatesBothContextAndFullResponse() {
        let response = CheckoutFinalizeResponse(
            headlessCheckoutId: "co_xyz",
            onramperTransactionId: "01JTXN0000000000000000000",
            headlessCheckoutData: HeadlessCheckoutData(
                checkoutPaymentType: .revolutPay,
                url: "https://pay.example.com",
                renderType: .deeplink
            )
        )

        let dto = BridgeMappers.fromNative(CheckoutEvent.checkoutFinalized(response))

        XCTAssertEqual(dto.kind, .checkoutFinalized)
        XCTAssertEqual(dto.checkoutId, "co_xyz")
        XCTAssertEqual(dto.renderContext?.url, "https://pay.example.com")
        XCTAssertEqual(dto.renderContext?.renderType, .deeplink)
        XCTAssertEqual(dto.renderContext?.paymentType, .revolutPay)
        // The finalizeResponse field carries the whole response for consumers
        // that want more than the summary renderContext.
        XCTAssertEqual(dto.finalizeResponse?.headlessCheckoutId, "co_xyz")
        XCTAssertEqual(dto.finalizeResponse?.headlessCheckoutData.url, "https://pay.example.com")
        XCTAssertEqual(dto.finalizeResponse?.headlessCheckoutData.renderType, .deeplink)
        XCTAssertEqual(dto.finalizeResponse?.headlessCheckoutData.checkoutPaymentType, .revolutPay)
    }

    func test_checkoutEvent_fromNative_renderingStarted_paymentTypeIsNil() {
        // Native renderingStarted carries only url + renderType. Payment type
        // should be nil here, not hardcoded — consumers who need it should
        // read state.rendering.paymentType instead.
        let dto = BridgeMappers.fromNative(
            CheckoutEvent.renderingStarted(
                url: URL(string: "https://render.example.com")!,
                renderType: .webview
            )
        )

        XCTAssertEqual(dto.kind, .renderingStarted)
        XCTAssertEqual(dto.renderContext?.url, "https://render.example.com")
        XCTAssertEqual(dto.renderContext?.renderType, .webview)
        XCTAssertNil(dto.renderContext?.paymentType)
    }

    func test_checkoutEvent_fromNative_completed() {
        let dto = BridgeMappers.fromNative(CheckoutEvent.completed(checkoutId: "co_done"))

        XCTAssertEqual(dto.kind, .completed)
        XCTAssertEqual(dto.checkoutId, "co_done")
    }

    func test_checkoutEvent_fromNative_failed() {
        let dto = BridgeMappers.fromNative(CheckoutEvent.failed(.deviceBlocked))

        XCTAssertEqual(dto.kind, .failed)
        XCTAssertEqual(dto.error?.kind, .deviceBlocked)
    }

    func test_checkoutEvent_fromNative_providerLifecycleEvents_mapToDedicatedKinds() {
        XCTAssertEqual(BridgeMappers.fromNative(CheckoutEvent.checkoutCancelled).kind, .checkoutCancelled)
        XCTAssertEqual(BridgeMappers.fromNative(CheckoutEvent.providerReady).kind, .providerReady)
        XCTAssertEqual(BridgeMappers.fromNative(CheckoutEvent.paymentAuthorized).kind, .paymentAuthorized)
        XCTAssertEqual(BridgeMappers.fromNative(CheckoutEvent.paymentProcessing).kind, .paymentProcessing)
        XCTAssertEqual(BridgeMappers.fromNative(CheckoutEvent.paymentCancelled).kind, .paymentCancelled)
    }

    func test_checkoutEvent_fromNative_providerError_carriesReason() {
        let dto = BridgeMappers.fromNative(CheckoutEvent.providerError(reason: "webview timeout"))

        XCTAssertEqual(dto.kind, .providerError)
        XCTAssertEqual(dto.providerReason, "webview timeout")
    }

    // MARK: - Button style (Dart -> Swift)

    func test_parseHexColor_sixDigits() {
        XCTAssertNotNil(BridgeMappers.parseHexColor("#ff8800"))
        XCTAssertNotNil(BridgeMappers.parseHexColor("ff8800"))
    }

    func test_parseHexColor_eightDigitsWithAlpha() {
        XCTAssertNotNil(BridgeMappers.parseHexColor("#ff8800aa"))
    }

    func test_parseHexColor_invalid_returnsNil() {
        XCTAssertNil(BridgeMappers.parseHexColor("nope"))
        XCTAssertNil(BridgeMappers.parseHexColor("#ff"))
        XCTAssertNil(BridgeMappers.parseHexColor("#gggggg"))
    }

    func test_checkoutButtonStyle_toNative_nilYieldsDefaults() {
        let style = BridgeMappers.toNative(nil as CheckoutButtonStyleDto?)
        let defaults = CheckoutButtonStyle()
        XCTAssertEqual(style.borderRadius, defaults.borderRadius)
    }

    func test_checkoutButtonStyle_toNative_customRadiusApplied() {
        let dto = CheckoutButtonStyleDto(
            backgroundColor: "#112233",
            foregroundColor: "#ffffff",
            borderRadius: 24.0
        )
        let style = BridgeMappers.toNative(dto)
        XCTAssertEqual(style.borderRadius, 24.0)
    }

    // MARK: - OnramperError (Swift -> Dart)

    func test_onramperError_notInitialized() {
        let dto = BridgeMappers.fromNative(OnramperError.notInitialized)
        XCTAssertEqual(dto.kind, .notInitialized)
        XCTAssertFalse(dto.recoverable)
        XCTAssertFalse(dto.message.isEmpty)
    }

    func test_onramperError_initializationFailed_carriesDebugInfo() {
        let dto = BridgeMappers.fromNative(OnramperError.initializationFailed("boom"))
        XCTAssertEqual(dto.kind, .initializationFailed)
        XCTAssertFalse(dto.recoverable)
        XCTAssertEqual(dto.debugInfo, "boom")
    }

    func test_onramperError_attestationFailed_carriesDebugInfo() {
        let dto = BridgeMappers.fromNative(OnramperError.attestationFailed("attest-bad"))
        XCTAssertEqual(dto.kind, .attestationFailed)
        XCTAssertFalse(dto.recoverable)
        XCTAssertEqual(dto.debugInfo, "attest-bad")
    }

    func test_onramperError_invalidStateTransition_carriesFromTo() {
        let dto = BridgeMappers.fromNative(OnramperError.invalidStateTransition(from: "idle", to: "completed"))
        XCTAssertEqual(dto.kind, .invalidStateTransition)
        XCTAssertFalse(dto.recoverable)
        XCTAssertEqual(dto.fromState, "idle")
        XCTAssertEqual(dto.toState, "completed")
    }

    func test_onramperError_invalidState_carriesExpectedActual() {
        let dto = BridgeMappers.fromNative(OnramperError.invalidState(expected: "ready", actual: "idle"))
        XCTAssertEqual(dto.kind, .invalidState)
        XCTAssertFalse(dto.recoverable)
        XCTAssertEqual(dto.expectedState, "ready")
        XCTAssertEqual(dto.actualState, "idle")
    }

    func test_onramperError_networkError_carriesCodeAndDebugInfo() {
        let dto = BridgeMappers.fromNative(OnramperError.networkError(code: 502, message: "bad gateway"))
        XCTAssertEqual(dto.kind, .networkError)
        XCTAssertTrue(dto.recoverable)
        XCTAssertEqual(dto.code, 502)
        XCTAssertEqual(dto.debugInfo, "bad gateway")
    }

    func test_onramperError_decodingError() {
        let dto = BridgeMappers.fromNative(OnramperError.decodingError("missing key"))
        XCTAssertEqual(dto.kind, .decodingError)
        XCTAssertFalse(dto.recoverable)
        XCTAssertEqual(dto.debugInfo, "missing key")
    }

    func test_onramperError_timeout() {
        let dto = BridgeMappers.fromNative(OnramperError.timeout)
        XCTAssertEqual(dto.kind, .timeout)
        XCTAssertTrue(dto.recoverable)
    }

    func test_onramperError_requirementNotSatisfied() {
        let dto = BridgeMappers.fromNative(OnramperError.requirementNotSatisfied("kyc"))
        XCTAssertEqual(dto.kind, .requirementNotSatisfied)
        XCTAssertTrue(dto.recoverable)
        XCTAssertEqual(dto.debugInfo, "kyc")
    }

    func test_onramperError_amountOutOfRange_carriesMinMax() {
        let dto = BridgeMappers.fromNative(OnramperError.amountOutOfRange(min: 20.0, max: 5000.0))
        XCTAssertEqual(dto.kind, .amountOutOfRange)
        XCTAssertTrue(dto.recoverable)
        XCTAssertEqual(dto.minAmount, 20.0)
        XCTAssertEqual(dto.maxAmount, 5000.0)
    }

    func test_onramperError_oidcFlowCancelled() {
        let dto = BridgeMappers.fromNative(OnramperError.oidcFlowCancelled)
        XCTAssertEqual(dto.kind, .oidcFlowCancelled)
        XCTAssertTrue(dto.recoverable)
    }

    func test_onramperError_oidcTokenExchangeFailed() {
        let dto = BridgeMappers.fromNative(OnramperError.oidcTokenExchangeFailed("bad token"))
        XCTAssertEqual(dto.kind, .oidcTokenExchangeFailed)
        XCTAssertFalse(dto.recoverable)
        XCTAssertEqual(dto.debugInfo, "bad token")
    }

    func test_onramperError_oidcFlowFailed() {
        let dto = BridgeMappers.fromNative(OnramperError.oidcFlowFailed("err"))
        XCTAssertEqual(dto.kind, .oidcFlowFailed)
        XCTAssertFalse(dto.recoverable)
        XCTAssertEqual(dto.debugInfo, "err")
    }

    func test_onramperError_userTokenInvalid() {
        let dto = BridgeMappers.fromNative(OnramperError.userTokenInvalid)
        XCTAssertEqual(dto.kind, .userTokenInvalid)
        XCTAssertTrue(dto.recoverable)
    }

    func test_onramperError_userTokenRefreshFailed() {
        let dto = BridgeMappers.fromNative(OnramperError.userTokenRefreshFailed("expired"))
        XCTAssertEqual(dto.kind, .userTokenRefreshFailed)
        XCTAssertTrue(dto.recoverable)
        XCTAssertEqual(dto.debugInfo, "expired")
    }

    func test_onramperError_webviewLoadFailed() {
        let dto = BridgeMappers.fromNative(OnramperError.webviewLoadFailed("404"))
        XCTAssertEqual(dto.kind, .webviewLoadFailed)
        XCTAssertFalse(dto.recoverable)
        XCTAssertEqual(dto.debugInfo, "404")
    }

    func test_onramperError_deepLinkFailed() {
        let dto = BridgeMappers.fromNative(OnramperError.deepLinkFailed("no app"))
        XCTAssertEqual(dto.kind, .deepLinkFailed)
        XCTAssertFalse(dto.recoverable)
        XCTAssertEqual(dto.debugInfo, "no app")
    }

    func test_onramperError_invalidRequest_carriesFieldAndDebug() {
        let dto = BridgeMappers.fromNative(OnramperError.invalidRequest(field: "amount", debugInfo: "negative"))
        XCTAssertEqual(dto.kind, .invalidRequest)
        XCTAssertTrue(dto.recoverable)
        XCTAssertEqual(dto.field, "amount")
        XCTAssertEqual(dto.debugInfo, "negative")
    }

    func test_onramperError_invalidRequest_nilsAllowed() {
        let dto = BridgeMappers.fromNative(OnramperError.invalidRequest(field: nil, debugInfo: nil))
        XCTAssertEqual(dto.kind, .invalidRequest)
        XCTAssertNil(dto.field)
        XCTAssertNil(dto.debugInfo)
    }

    func test_onramperError_quoteUnavailable() {
        let dto = BridgeMappers.fromNative(OnramperError.quoteUnavailable(debugInfo: "no liquidity"))
        XCTAssertEqual(dto.kind, .quoteUnavailable)
        XCTAssertTrue(dto.recoverable)
        XCTAssertEqual(dto.debugInfo, "no liquidity")
    }

    func test_onramperError_checkoutForbidden() {
        let dto = BridgeMappers.fromNative(OnramperError.checkoutForbidden(debugInfo: "region"))
        XCTAssertEqual(dto.kind, .checkoutForbidden)
        XCTAssertFalse(dto.recoverable)
        XCTAssertEqual(dto.debugInfo, "region")
    }

    func test_onramperError_temporaryFailure_carriesRetryAndDebug() {
        let dto = BridgeMappers.fromNative(OnramperError.temporaryFailure(retryAfter: 30.0, debugInfo: "rate limit"))
        XCTAssertEqual(dto.kind, .temporaryFailure)
        XCTAssertTrue(dto.recoverable)
        XCTAssertEqual(dto.retryAfterSeconds, 30.0)
        XCTAssertEqual(dto.debugInfo, "rate limit")
    }

    func test_onramperError_unrecoverable() {
        let dto = BridgeMappers.fromNative(OnramperError.unrecoverable(debugInfo: "fatal"))
        XCTAssertEqual(dto.kind, .unrecoverable)
        XCTAssertFalse(dto.recoverable)
        XCTAssertEqual(dto.debugInfo, "fatal")
    }

    func test_onramperError_configurationError() {
        let dto = BridgeMappers.fromNative(OnramperError.configurationError(reason: "missing apiKey"))
        XCTAssertEqual(dto.kind, .configurationError)
        XCTAssertFalse(dto.recoverable)
        XCTAssertEqual(dto.debugInfo, "missing apiKey")
    }

    func test_onramperError_deviceBlocked() {
        let dto = BridgeMappers.fromNative(OnramperError.deviceBlocked)
        XCTAssertEqual(dto.kind, .deviceBlocked)
        XCTAssertFalse(dto.recoverable)
    }

    func test_onramperError_securityStorageFailed_carriesCode() {
        let dto = BridgeMappers.fromNative(OnramperError.securityStorageFailed(status: -25300))
        XCTAssertEqual(dto.kind, .securityStorageFailed)
        XCTAssertFalse(dto.recoverable)
        XCTAssertEqual(dto.code, -25300)
    }

    func test_onramperError_securityTrustFailed_carriesHost() {
        let dto = BridgeMappers.fromNative(OnramperError.securityTrustFailed(host: "api.example.com"))
        XCTAssertEqual(dto.kind, .securityTrustFailed)
        XCTAssertFalse(dto.recoverable)
        XCTAssertEqual(dto.host, "api.example.com")
    }

    /// Iterates every native case to confirm each produces a non-empty
    /// `message` and a defined `kind`. If a new case is added to
    /// `OnramperError` without updating the mapper, this fixture array
    /// will not type-check and force the addition.
    func test_onramperError_allCases_produceNonEmptyMessage() {
        let fixtures: [OnramperError] = [
            .notInitialized,
            .initializationFailed("x"),
            .attestationFailed("x"),
            .invalidStateTransition(from: "a", to: "b"),
            .invalidState(expected: "a", actual: "b"),
            .networkError(code: 500, message: "x"),
            .decodingError("x"),
            .timeout,
            .requirementNotSatisfied("x"),
            .amountOutOfRange(min: 1, max: 2),
            .oidcFlowCancelled,
            .oidcTokenExchangeFailed("x"),
            .oidcFlowFailed("x"),
            .userTokenInvalid,
            .userTokenRefreshFailed("x"),
            .webviewLoadFailed("x"),
            .deepLinkFailed("x"),
            .invalidRequest(field: nil, debugInfo: nil),
            .quoteUnavailable(debugInfo: nil),
            .checkoutForbidden(debugInfo: nil),
            .temporaryFailure(retryAfter: nil, debugInfo: nil),
            .unrecoverable(debugInfo: nil),
            .configurationError(reason: "x"),
            .deviceBlocked,
            .securityStorageFailed(status: -1),
            .securityTrustFailed(host: "example.com"),
        ]

        XCTAssertEqual(fixtures.count, 26)
        for native in fixtures {
            let dto = BridgeMappers.fromNative(native)
            XCTAssertFalse(dto.message.isEmpty, "Empty message for native case: \(native)")
        }
    }
}

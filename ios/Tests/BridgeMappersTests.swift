import XCTest
@testable import onramper_sdk
import OnramperSDK

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
            networkFee: 0.5,
            transactionFee: 1.25,
            payout: 100.0,
            paymentMethod: "credit_card",
            recommendations: ["best_rate", "fastest"],
            errors: nil
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
        XCTAssertNil(dto.errors)
    }

    func test_quoteResponse_fromNative_allNilFields_mapsToAllNil() {
        let native = QuoteResponse()

        let dto = BridgeMappers.fromNative(native)

        XCTAssertNil(dto.quoteId)
        XCTAssertNil(dto.ramp)
        XCTAssertNil(dto.rate)
        XCTAssertNil(dto.networkFee)
        XCTAssertNil(dto.transactionFee)
        XCTAssertNil(dto.payout)
        XCTAssertNil(dto.paymentMethod)
        XCTAssertNil(dto.recommendations)
        XCTAssertNil(dto.errors)
    }

    func test_quoteResponse_fromNative_withErrors_mapsErrorsElementwise() {
        let native = QuoteResponse(
            errors: [
                QuoteError(type: "amount_too_low", message: "Amount below minimum"),
                QuoteError(type: nil, message: "Generic error"),
                QuoteError(type: "outage", message: nil),
            ]
        )

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.errors?.count, 3)
        XCTAssertEqual(dto.errors?[0].type, "amount_too_low")
        XCTAssertEqual(dto.errors?[0].message, "Amount below minimum")
        XCTAssertNil(dto.errors?[1].type)
        XCTAssertEqual(dto.errors?[1].message, "Generic error")
        XCTAssertEqual(dto.errors?[2].type, "outage")
        XCTAssertNil(dto.errors?[2].message)
    }

    func test_quoteError_fromNative_mapsFields() {
        let native = QuoteError(type: "x", message: "y")

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.type, "x")
        XCTAssertEqual(dto.message, "y")
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
            onramp: "moonpay",
            source: "USD",
            amount: 100.0,
            type: .buy,
            paymentMethod: "credit_card",
            wallet: WalletInfoDto(network: "ethereum", address: "0xabc", memo: nil),
            destination: "BTC",
            country: "US",
            subdivision: "US-CA"
        )

        let native = BridgeMappers.toNative(dto)

        XCTAssertEqual(native.onramp, "moonpay")
        // Native init lowercases source/destination/country/subdivision; the
        // mapper does not pre-lowercase.
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
            onramp: "x",
            source: "usd",
            amount: 1.0,
            type: .sell,
            paymentMethod: "pm",
            wallet: WalletInfoDto(network: "n", address: "a", memo: nil),
            destination: nil,
            country: nil,
            subdivision: nil
        )

        let native = BridgeMappers.toNative(dto)

        XCTAssertNil(native.destination)
        XCTAssertNil(native.country)
        XCTAssertNil(native.subdivision)
        XCTAssertEqual(native.type, .sell)
    }

    func test_checkoutIntentRequestDto_toNative_passesThroughOnlyOnramps() {
        let dto = CheckoutIntentRequestDto(
            transactionData: OnramperTransactionDataDto(
                onramp: "moonpay",
                source: "usd",
                amount: 50.0,
                type: .buy,
                paymentMethod: "pm",
                wallet: WalletInfoDto(network: "ethereum", address: "0x", memo: nil)
            ),
            onlyOnramps: ["moonpay", "transak"]
        )

        let native = BridgeMappers.toNative(dto)

        XCTAssertEqual(native.onlyOnramps, ["moonpay", "transak"])
        XCTAssertEqual(native.onramperTransactionData.onramp, "moonpay")
        XCTAssertEqual(native.onramperTransactionData.amount, 50.0)
    }

    func test_checkoutIntentRequestDto_toNative_nilOnlyOnramps() {
        let dto = CheckoutIntentRequestDto(
            transactionData: OnramperTransactionDataDto(
                onramp: "x",
                source: "usd",
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
    }

    func test_checkoutRequirementType_toNative() {
        XCTAssertEqual(BridgeMappers.toNative(CheckoutRequirementTypeDto.tos), .tos)
        XCTAssertEqual(BridgeMappers.toNative(CheckoutRequirementTypeDto.amountLimit), .amountLimit)
        XCTAssertEqual(BridgeMappers.toNative(CheckoutRequirementTypeDto.userInfo), .userInfo)
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

    func test_amountLimitRequirement_fromNative() {
        let native = AmountLimitRequirement(providerId: "moonpay", minAmountLimit: 10.0, maxAmountLimit: 1000.0)

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.providerId, "moonpay")
        XCTAssertEqual(dto.minAmountLimit, 10.0)
        XCTAssertEqual(dto.maxAmountLimit, 1000.0)
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

    func test_checkoutRequirement_fromNative_tos_populatesOnlyTos() {
        let native = CheckoutRequirement.tos(ToSRequirement(providerId: "p", items: []))

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.type, .tos)
        XCTAssertNotNil(dto.tos)
        XCTAssertNil(dto.amountLimit)
        XCTAssertNil(dto.userInfo)
    }

    func test_checkoutRequirement_fromNative_amountLimit_populatesOnlyAmount() {
        let native = CheckoutRequirement.amountLimit(AmountLimitRequirement(providerId: "p"))

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.type, .amountLimit)
        XCTAssertNil(dto.tos)
        XCTAssertNotNil(dto.amountLimit)
        XCTAssertNil(dto.userInfo)
    }

    func test_checkoutRequirement_fromNative_userInfo_populatesOnlyUserInfo() {
        let native = CheckoutRequirement.userInfo(UserInfoRequirement(providerId: "p", fields: []))

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.type, .userInfo)
        XCTAssertNil(dto.tos)
        XCTAssertNil(dto.amountLimit)
        XCTAssertNotNil(dto.userInfo)
    }

    func test_checkoutIntentResponse_fromNative_allRequirementsPresent() {
        let native = CheckoutIntentResponse(
            quote: QuoteResponse(quoteId: "q1"),
            headlessCheckoutId: "co_123",
            checkoutRequirements: [
                .tos(ToSRequirement(providerId: "p", items: [])),
                .amountLimit(AmountLimitRequirement(providerId: "p", minAmountLimit: 1, maxAmountLimit: 100)),
                .userInfo(UserInfoRequirement(providerId: "p", fields: [])),
            ]
        )

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.headlessCheckoutId, "co_123")
        XCTAssertEqual(dto.quote.quoteId, "q1")
        XCTAssertEqual(dto.requirements.count, 3)
        XCTAssertEqual(dto.requirements[0].type, .tos)
        XCTAssertEqual(dto.requirements[1].type, .amountLimit)
        XCTAssertEqual(dto.requirements[2].type, .userInfo)
    }

    func test_checkoutIntentResponse_fromNative_emptyRequirements() {
        let native = CheckoutIntentResponse(
            quote: QuoteResponse(),
            headlessCheckoutId: "co_456",
            checkoutRequirements: []
        )

        let dto = BridgeMappers.fromNative(native)

        XCTAssertEqual(dto.headlessCheckoutId, "co_456")
        XCTAssertTrue(dto.requirements.isEmpty)
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

    func test_checkoutEvent_fromNative_checkoutFinalized() {
        let response = CheckoutFinalizeResponse(
            headlessCheckoutId: "co_xyz",
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
    }

    func test_checkoutEvent_fromNative_renderingStarted_defaultsPaymentTypeApplePay() {
        let dto = BridgeMappers.fromNative(
            CheckoutEvent.renderingStarted(
                url: URL(string: "https://render.example.com")!,
                renderType: .webview
            )
        )

        XCTAssertEqual(dto.kind, .renderingStarted)
        XCTAssertEqual(dto.renderContext?.url, "https://render.example.com")
        XCTAssertEqual(dto.renderContext?.renderType, .webview)
        XCTAssertEqual(dto.renderContext?.paymentType, .applePay)
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
}

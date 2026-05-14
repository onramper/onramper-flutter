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
}

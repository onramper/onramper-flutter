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
}

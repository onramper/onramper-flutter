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
}

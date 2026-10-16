import XCTest
import SwiftUI
@testable import onramper_flutter

final class CheckoutButtonRegistryTests: XCTestCase {
    func test_consumeOnce() async {
        let registry = CheckoutButtonRegistry()
        let h = await registry.storeView(AnyView(EmptyView()))
        let first = await registry.consume(h)
        let second = await registry.consume(h)
        XCTAssertNotNil(first)
        XCTAssertNil(second)
    }

    func test_expiredHandleIsNotDelivered() async {
        final class Clock: @unchecked Sendable { var now = Date(timeIntervalSince1970: 0) }
        let clock = Clock()
        let registry = CheckoutButtonRegistry(ttl: 300, now: { clock.now })
        let h = await registry.storeView(AnyView(EmptyView()))
        clock.now = Date(timeIntervalSince1970: 301)
        let view = await registry.consume(h)
        XCTAssertNil(view)
    }
}

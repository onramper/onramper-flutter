import XCTest
@testable import onramper_flutter
import OnramperSDK

@MainActor
final class CheckoutRequirementsCollectorTests: XCTestCase {
    private let staleLogin = [CheckoutRequirement.tos(ToSRequirement(providerId: "stale", items: []))]

    /// A superseded call's late `didRequireLogin` must not leak into the
    /// newer call that then becomes ready to checkout.
    func test_lateLoginFromSupersededCall_isClearedByNewCheckout() {
        let c = CheckoutRequirementsCollector()
        c.loginRequired(staleLogin)      // late callback from call A
        c.checkoutStarted("co_B")        // call B starts
        c.readyToCheckout()              // B needs no login
        XCTAssertEqual(c.headlessCheckoutId, "co_B")
        XCTAssertEqual(c.requireLoginRequirements?.count, 0)
    }

    func test_loginRequiredAfterStart_isKept() {
        let c = CheckoutRequirementsCollector()
        c.checkoutStarted("co_B")
        c.loginRequired(staleLogin)
        XCTAssertEqual(c.requireLoginRequirements?.count, 1)
    }
}

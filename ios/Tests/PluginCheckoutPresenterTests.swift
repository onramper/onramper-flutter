#if canImport(UIKit)
import XCTest
import UIKit
import SwiftUI
@testable import onramper_sdk
import OnramperSDK

/// Tests for `PluginCheckoutPresenter`. The presenter wraps SwiftUI's
/// `UIHostingController` around the SDK's `OnramperCheckoutView` and presents
/// it modally over a parent view controller.
///
/// `pod lib lint`'s test_spec runs in a host app where `UIApplication` is
/// available but there is no key UIWindow attached to a UIWindowScene by
/// default. To reliably present a modal in this environment, the integration-
/// style test below builds its own `UIWindow`, attaches it to a scene, and
/// presents from a parent it controls — independent of the plugin's
/// `findRootViewController` static helper (which is intentionally tested
/// separately via the plugin's `presentCheckout`).
@MainActor
final class PluginCheckoutPresenterTests: XCTestCase {

    func test_init_doesNotCrash() throws {
        // Smoke: constructing the presenter should never touch the view
        // hierarchy or kick off any async work. Subscription to `events` only
        // starts when `present(from:)` is called.
        let plugin = OnramperSdkPlugin()
        try plugin.configure(config: ConfigurationDto(
            apiKey: "pk_x",
            clientId: "01HPRESENTERTEST",
            environment: .development,
            theme: .system,
            logLevel: .off
        ))
        let client = try XCTUnwrap(plugin.testClient(), "configure should create a client")
        _ = PluginCheckoutPresenter(client: client)
    }

    func test_present_attachesModalToParent() async throws {
        let plugin = OnramperSdkPlugin()
        try plugin.configure(config: ConfigurationDto(
            apiKey: "pk_x",
            clientId: "01HPRESENTERTEST",
            environment: .development,
            theme: .system,
            logLevel: .off
        ))
        let client = try XCTUnwrap(plugin.testClient())

        let parent = UIViewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = parent
        window.isHidden = false
        // `makeKeyAndVisible()` is the standard way to force a window into the
        // hierarchy in test harnesses; without it `present(_:animated:)` is a
        // no-op because the window has no scene attachment.
        window.makeKeyAndVisible()

        let presenter = PluginCheckoutPresenter(client: client)
        presenter.present(from: parent)

        // `present(_:animated:)` schedules the transition on the next runloop
        // tick. Spin briefly so the presentedViewController hook-up completes.
        let exp = expectation(description: "modal attached")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 1.0)

        XCTAssertNotNil(parent.presentedViewController, "expected a modal to be presented over the parent")
        XCTAssertTrue(parent.presentedViewController is UIHostingController<OnramperCheckoutView>,
                      "expected a UIHostingController hosting OnramperCheckoutView")
    }
}
#endif

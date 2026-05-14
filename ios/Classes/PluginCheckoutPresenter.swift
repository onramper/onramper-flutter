#if canImport(UIKit)
import UIKit
import SwiftUI
import OnramperSDK

/// Hosts the native `OnramperCheckoutView` inside a `UIHostingController` and
/// presents it modally over the Flutter app's root view controller.
///
/// The Flutter hybrid model renders the Buy button on the Dart side, so we do
/// not use `OnramperCheckoutButton`. When Dart calls `presentCheckout()`, the
/// plugin instantiates this presenter, which drives the rendering / completed
/// / failed phases of the native flow.
///
/// Lifetime: the plugin retains a single `activePresenter` while a sheet is on
/// screen. On `.completed` or `.failed`, the presenter dismisses the hosting
/// controller and the event-observation task exits, allowing the plugin to
/// release it.
@MainActor
final class PluginCheckoutPresenter {
    private let client: OnramperClient
    private weak var presentedHost: UIViewController?
    private var dismissTask: Task<Void, Never>?
    /// Optional hook invoked after the modal has been dismissed in response to
    /// a terminal event. Used by the plugin to drop its strong reference.
    var onDismissed: (@MainActor () -> Void)?

    init(client: OnramperClient) {
        self.client = client
    }

    /// Presents the native checkout view modally over `parent` (typically the
    /// Flutter app's root view controller). Subscribes to `client.events` and
    /// auto-dismisses on `.completed` or `.failed`. There is no native
    /// `closed` event, so user-initiated dismissal (swipe-down on a non-
    /// fullScreen sheet) is not currently bridged — we present fullScreen to
    /// keep the contract explicit: native owns the modal until terminal.
    func present(from parent: UIViewController) {
        let checkoutView = OnramperCheckoutView(sdk: client)
        let host = UIHostingController(rootView: checkoutView)
        host.modalPresentationStyle = .fullScreen
        parent.present(host, animated: true)
        presentedHost = host
        observeForAutoDismiss()
    }

    private func observeForAutoDismiss() {
        let client = self.client
        dismissTask = Task { @MainActor [weak self] in
            for await event in client.events {
                switch event {
                case .completed, .failed:
                    guard let self else { return }
                    self.presentedHost?.dismiss(animated: true)
                    self.onDismissed?()
                    return
                default:
                    continue
                }
            }
        }
    }

    deinit {
        dismissTask?.cancel()
    }
}
#endif

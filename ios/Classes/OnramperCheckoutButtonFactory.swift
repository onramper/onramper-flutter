import Flutter
import UIKit
import SwiftUI
import OnramperSDK

/// View type identifier registered with Flutter's platform-view channel.
let kOnramperCheckoutButtonViewType = "OnramperCheckoutButton"

/// Registers `OnramperCheckoutButtonFactory` with the Flutter plugin registrar so
/// Dart can embed the native `OnramperCheckoutButton` via `UiKitView`.
func registerOnramperCheckoutButtonFactory(registrar: FlutterPluginRegistrar) {
    registrar.register(
        OnramperCheckoutButtonFactory(messenger: registrar.messenger()),
        withId: kOnramperCheckoutButtonViewType
    )
}

// MARK: - Factory

final class OnramperCheckoutButtonFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let handle = (args as? [String: Any])?["handle"] as? String ?? ""
        return OnramperCheckoutButtonPlatformView(frame: frame, handle: handle)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

// MARK: - Platform view

final class OnramperCheckoutButtonPlatformView: NSObject, FlutterPlatformView {
    private let container: CheckoutButtonContainerView

    init(frame: CGRect, handle: String) {
        container = CheckoutButtonContainerView(frame: frame, handle: handle)
        super.init()
    }

    func view() -> UIView { container }
}

// MARK: - Container UIView

/// Hosts the SwiftUI OnramperCheckoutButton inside a UIHostingController.
/// Attaches the hosting controller to the nearest FlutterViewController when
/// it enters the window so that sheets (OIDC login, payment webview) can present.
private final class CheckoutButtonContainerView: UIView {
    private var hostingController: UIHostingController<AnyView>?
    private let handle: String

    init(frame: CGRect, handle: String) {
        self.handle = handle
        super.init(frame: frame)
        backgroundColor = .clear
        Task { await mountButton() }
    }

    required init?(coder: NSCoder) { fatalError() }

    @MainActor
    private func mountButton() async {
        guard let view = await CheckoutButtonRegistry.shared.consume(handle) else { return }
        let hc = UIHostingController(rootView: view)
        hc.view.backgroundColor = .clear
        addSubview(hc.view)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: topAnchor),
            hc.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hc.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        hostingController = hc
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        guard let hc = hostingController else { return }
        if newWindow != nil {
            // Attach to nearest VC so sheets can present over the app.
            if let parent = newWindow?.rootViewController?.topMostPresentedViewController() {
                parent.addChild(hc)
                hc.didMove(toParent: parent)
            }
        } else {
            hc.willMove(toParent: nil)
            hc.removeFromParent()
        }
    }
}

private extension UIViewController {
    func topMostPresentedViewController() -> UIViewController {
        var top: UIViewController = self
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

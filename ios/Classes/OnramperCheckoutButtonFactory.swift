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
        let sizing = CheckoutButtonFlutterApi(binaryMessenger: messenger, messageChannelSuffix: "\(viewId)")
        return OnramperCheckoutButtonPlatformView(frame: frame, handle: handle, sizing: sizing)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

// MARK: - Platform view

final class OnramperCheckoutButtonPlatformView: NSObject, FlutterPlatformView {
    private let container: CheckoutButtonContainerView

    init(frame: CGRect, handle: String, sizing: CheckoutButtonFlutterApiProtocol) {
        container = CheckoutButtonContainerView(frame: frame, handle: handle, sizing: sizing)
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
    private let sizing: CheckoutButtonFlutterApiProtocol
    private var heightReporter = HeightReporter()

    init(frame: CGRect, handle: String, sizing: CheckoutButtonFlutterApiProtocol) {
        self.handle = handle
        self.sizing = sizing
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
        Task { await mountButton() }
    }

    required init?(coder: NSCoder) { fatalError() }

    @MainActor
    private func mountButton() async {
        guard let button = await CheckoutButtonRegistry.shared.consume(handle) else {
            sizing.onUnavailable { _ in }
            return
        }
        let measured = AnyView(
            button
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { proxy in
                    // Zero-width first pass reports a bogus height; ignore it.
                    Color.clear.preference(
                        key: CheckoutContentHeightKey.self,
                        value: proxy.size.width > 0 ? proxy.size.height : 0
                    )
                })
                .onPreferenceChange(CheckoutContentHeightKey.self) { [weak self] height in
                    Task { @MainActor in self?.report(height) }
                }
        )
        let hc = UIHostingController(rootView: measured)
        hc.view.backgroundColor = .clear
        if #available(iOS 16.4, *) { hc.safeAreaRegions = [] }
        addSubview(hc.view)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: topAnchor),
            hc.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hc.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        hostingController = hc
        // Race guard: if the view entered a window before mountButton() completed,
        // willMove(toWindow:) fired without a hostingController and couldn't attach.
        // Attach now if we are already in a window.
        if let currentWindow = window,
           let parent = currentWindow.rootViewController?.topMostPresentedViewController(),
           hc.parent == nil {
            parent.addChild(hc)
            hc.didMove(toParent: parent)
        }
    }

    @MainActor
    private func report(_ height: CGFloat) {
        guard let value = heightReporter.accept(height) else { return }
        sizing.onHeightChanged(height: Double(value)) { _ in }
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        guard let hc = hostingController else { return }
        if newWindow != nil {
            // Attach to nearest VC so sheets can present over the app.
            // Guard against double-attachment in case mountButton() already attached.
            if hc.parent == nil,
               let parent = newWindow?.rootViewController?.topMostPresentedViewController() {
                parent.addChild(hc)
                hc.didMove(toParent: parent)
            }
        } else {
            hc.willMove(toParent: nil)
            hc.removeFromParent()
        }
    }
}

/// Drops zero heights and changes of 0.5pt or less so Dart only relayouts on
/// real content changes.
struct HeightReporter {
    private(set) var lastReported: CGFloat = 0
    mutating func accept(_ height: CGFloat) -> CGFloat? {
        guard height > 0, abs(height - lastReported) > 0.5 else { return nil }
        lastReported = height
        return height
    }
}

private struct CheckoutContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private extension UIViewController {
    func topMostPresentedViewController() -> UIViewController {
        var top: UIViewController = self
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

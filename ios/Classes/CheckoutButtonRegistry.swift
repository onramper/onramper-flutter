import Foundation
import OnramperSDK
import SwiftUI

/// Thread-safe store mapping ULID handles to captured OnramperCheckoutButton views.
/// Lifetime: button is stored after getCheckoutRequirements, consumed once by the
/// platform view, and dropped on reset/dispose or if a new requirements call replaces it.
actor CheckoutButtonRegistry {
    static let shared = CheckoutButtonRegistry()

    private var entries: [String: AnyView] = [:]

    func store(_ button: OnramperCheckoutButton) -> String {
        let handle = Self.makeHandle()
        entries[handle] = AnyView(button)
        return handle
    }

    func consume(_ handle: String) -> AnyView? {
        entries[handle]
    }

    func drop(_ handle: String) {
        entries.removeValue(forKey: handle)
    }

    func dropAll() {
        entries.removeAll()
    }

    private static func makeHandle() -> String {
        UUID().uuidString
    }
}

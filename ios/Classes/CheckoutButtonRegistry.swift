import Foundation
import OnramperSDK
import SwiftUI

/// Thread-safe store mapping handles to prepared OnramperCheckoutButton views.
/// Lifetime: stored after getCheckoutRequirements, consumed once by the
/// platform view, and dropped when superseded, on reset/signOut/dispose, or
/// after `ttl` seconds.
actor CheckoutButtonRegistry {
    static let shared = CheckoutButtonRegistry()

    private struct Entry {
        let view: AnyView
        let createdAt: Date
    }

    private var entries: [String: Entry] = [:]
    private let ttl: TimeInterval
    private let now: @Sendable () -> Date

    init(ttl: TimeInterval = 300, now: @escaping @Sendable () -> Date = { Date() }) {
        self.ttl = ttl
        self.now = now
    }

    func store(_ button: OnramperCheckoutButton) -> String {
        storeView(AnyView(button))
    }

    func storeView(_ view: AnyView) -> String {
        let handle = UUID().uuidString
        entries[handle] = Entry(view: view, createdAt: now())
        return handle
    }

    /// Removes on consume so the view isn't retained after the platform view
    /// claims it. Returns nil for unknown, dropped or expired handles.
    func consume(_ handle: String) -> AnyView? {
        guard let entry = entries.removeValue(forKey: handle),
              now().timeIntervalSince(entry.createdAt) < ttl else { return nil }
        return entry.view
    }

    func drop(_ handle: String) {
        entries.removeValue(forKey: handle)
    }

    func dropAll() {
        entries.removeAll()
    }
}

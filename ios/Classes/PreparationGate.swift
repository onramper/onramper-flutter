import Foundation

/// Generation counter for checkout preparations. The plugin owns one native
/// client, so a single counter on the main actor is enough. A newer
/// `getCheckoutRequirements`, or a reset / signOut / dispose, supersedes
/// every earlier in-flight preparation.
@MainActor
final class PreparationGate {
    private(set) var generation = 0

    func begin() -> Int {
        generation += 1
        return generation
    }

    func invalidate() { generation += 1 }

    func isCurrent(_ g: Int) -> Bool { g == generation }
}

import XCTest
@testable import onramper_flutter

@MainActor
final class PreparationGateTests: XCTestCase {
    func test_newerBeginSupersedesOlder() {
        let gate = PreparationGate()
        let first = gate.begin()
        let second = gate.begin()
        XCTAssertFalse(gate.isCurrent(first))
        XCTAssertTrue(gate.isCurrent(second))
    }

    func test_invalidateSupersedesInFlight() {
        let gate = PreparationGate()
        let g = gate.begin()
        gate.invalidate()
        XCTAssertFalse(gate.isCurrent(g))
    }
}

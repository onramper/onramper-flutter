import XCTest
@testable import onramper_flutter

final class HeightReporterTests: XCTestCase {
    func test_ignoresZeroAndSubPointChanges() {
        var r = HeightReporter()
        XCTAssertNil(r.accept(0))
        XCTAssertEqual(r.accept(56), 56)
        XCTAssertNil(r.accept(56.3))
        XCTAssertEqual(r.accept(92), 92)
        XCTAssertNil(r.accept(-1))
    }
}

import XCTest
@testable import SignForge

final class EntitlementsDiffTests: XCTestCase {
    func testCompareFindsMissingAndDifferentKeys() {
        let differences = EntitlementsDiff().compare(app: ["a": "1", "b": "2"], profile: ["a": "9", "c": "3"])
        XCTAssertTrue(differences.contains { $0.key == "a" && $0.kind == .different })
        XCTAssertTrue(differences.contains { $0.key == "b" && $0.kind == .missingInProfile })
        XCTAssertTrue(differences.contains { $0.key == "c" && $0.kind == .missingInApp })
    }
}

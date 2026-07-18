import XCTest
@testable import SignForge

final class DERTests: XCTestCase {
    func testShortLengthEncoding() {
        XCTAssertEqual(Array(DER.length(3)), [3])
    }

    func testLongLengthEncoding() {
        XCTAssertEqual(Array(DER.length(256)), [0x82, 0x01, 0x00])
    }
}

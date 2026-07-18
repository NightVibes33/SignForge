import XCTest
@testable import SignForge

final class Base64URLTests: XCTestCase {
    func testBase64URLRemovesPaddingAndUnsafeCharacters() {
        let encoded = Data([251, 255, 255]).base64URLString
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
        XCTAssertFalse(encoded.contains("="))
    }
}

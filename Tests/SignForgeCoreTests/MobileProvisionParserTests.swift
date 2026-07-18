import XCTest
@testable import SignForge

final class MobileProvisionParserTests: XCTestCase {
    func testParsesBasicProfileFields() {
        let plist = """
        <plist><dict>
        <key>Name</key><string>Dev Profile</string>
        <key>UUID</key><string>PROFILE-UUID</string>
        <key>application-identifier</key><string>TEAM123.com.example.app</string>
        </dict></plist>
        """

        let profile = MobileProvisionParser().parse(data: Data(plist.utf8), fallbackName: "fallback")

        XCTAssertEqual(profile.name, "Dev Profile")
        XCTAssertEqual(profile.uuid, "PROFILE-UUID")
        XCTAssertEqual(profile.bundleIdentifier, "com.example.app")
    }
}

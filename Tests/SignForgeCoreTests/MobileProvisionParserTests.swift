import XCTest
@testable import SignForge

final class MobileProvisionParserTests: XCTestCase {
    func testParsesBasicProfileFields() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
        <key>Name</key><string>Dev Profile</string>
        <key>UUID</key><string>PROFILE-UUID</string>
        <key>Entitlements</key><dict><key>application-identifier</key><string>TEAM123.com.example.app</string></dict>
        </dict></plist>
        """

        let profile = MobileProvisionParser().parse(data: Data(plist.utf8), fallbackName: "fallback")

        XCTAssertEqual(profile.name, "Dev Profile")
        XCTAssertEqual(profile.uuid, "PROFILE-UUID")
        XCTAssertEqual(profile.bundleIdentifier, "com.example.app")
    }

    func testExportsEntitlementsPlist() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
        <key>Entitlements</key><dict><key>application-identifier</key><string>TEAM123.com.example.app</string></dict>
        </dict></plist>
        """

        let entitlements = MobileProvisionParser().entitlementsPlist(data: Data(plist.utf8))

        XCTAssertTrue(entitlements?.contains("application-identifier") == true)
    }
}

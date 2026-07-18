import XCTest
@testable import SignForge

final class ArtifactWorkflowTests: XCTestCase {
    func testCIManifestIncludesCredentialAndSelectedAssets() {
        let credential = AppleCredential(name: "Team", issuerID: "issuer", keyID: "key", teamID: "team", p8KeyPreview: "")
        let certificate = CertificateRecord(name: "Cert", type: .appleDistribution, serialNumber: "serial", fingerprint: "AA:BB", expiresAt: Date(), matchingKeyID: nil)
        let profile = ProvisioningProfileRecord(name: "Profile", uuid: "uuid", type: .adHoc, bundleIdentifier: "com.example.app", certificateFingerprints: ["AA:BB"], deviceUDIDs: [], entitlements: [:], expiresAt: Date())

        let package = ArtifactWorkflow().makeCIManifest(credential: credential, certificate: certificate, profile: profile)
        let text = package.payload.exportText

        XCTAssertTrue(text.contains("APP_STORE_CONNECT_ISSUER_ID=issuer"))
        XCTAssertTrue(text.contains("SIGNING_CERTIFICATE_SHA256=AA:BB"))
        XCTAssertTrue(text.contains("PROVISIONING_PROFILE_UUID=uuid"))
    }
}

import XCTest
@testable import SignForge

final class ValidationEngineTests: XCTestCase {
    func testReadyWorkspaceWhenCertificateProfileAndBundleMatch() {
        var state = SignForgeState.preview
        let cert = state.certificates[0]
        var profile = state.profiles[0]
        profile.certificateFingerprints = [cert.fingerprint]
        state.profiles[0] = profile
        var workspace = state.workspaces[0]
        workspace.selectedCertificateID = cert.id
        workspace.selectedProfileID = profile.id

        let findings = ValidationEngine().findings(for: workspace, state: state)

        XCTAssertEqual(findings.first?.severity, .ready)
    }

    func testBundleMismatchBlocksSigning() {
        var state = SignForgeState.preview
        let cert = state.certificates[0]
        let profile = state.profiles[0]
        var workspace = state.workspaces[0]
        workspace.bundleIdentifier = "com.other.app"
        workspace.selectedCertificateID = cert.id
        workspace.selectedProfileID = profile.id

        let findings = ValidationEngine().findings(for: workspace, state: state)

        XCTAssertTrue(findings.contains { $0.title == "Bundle mismatch" })
    }
}

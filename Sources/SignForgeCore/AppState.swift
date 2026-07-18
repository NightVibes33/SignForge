import Foundation

struct SignForgeState: Codable {
    var credentials: [AppleCredential] = []
    var keys: [SigningKey] = []
    var certificates: [CertificateRecord] = []
    var bundleIDs: [BundleIDRecord] = []
    var devices: [DeviceRecord] = []
    var profiles: [ProvisioningProfileRecord] = []
    var workspaces: [ProjectWorkspace] = []
    var artifacts: [ArtifactRecord] = []
    var audit: [AuditEvent] = []

    static let preview = SignForgeState(
        credentials: [AppleCredential(name: "Primary team", issuerID: "issuer-id", keyID: "ABC123DEFG", teamID: "TEAM123456", p8KeyPreview: "-----BEGIN PRIVATE KEY-----")],
        keys: [SigningKey(label: "Distribution export key", algorithm: "RSA 2048", fingerprint: "A1:B2:C3:D4", exportable: true)],
        certificates: [CertificateRecord(name: "Apple Distribution", type: .appleDistribution, serialNumber: "7F001A", fingerprint: "A1:B2:C3:D4", expiresAt: Calendar.current.date(byAdding: .day, value: 278, to: Date()) ?? Date(), matchingKeyID: nil)],
        bundleIDs: [BundleIDRecord(identifier: "com.example.app", name: "Example App", capabilities: ["Associated domains", "Keychain sharing"])],
        devices: [DeviceRecord(name: "Dev iPhone", udid: "00008110-001A", platform: "iOS", enabled: true)],
        profiles: [ProvisioningProfileRecord(name: "Example Ad Hoc", uuid: UUID().uuidString, type: .adHoc, bundleIdentifier: "com.example.app", certificateFingerprints: ["A1:B2:C3:D4"], deviceUDIDs: ["00008110-001A"], entitlements: ["application-identifier": "TEAM123456.com.example.app"], expiresAt: Calendar.current.date(byAdding: .day, value: 120, to: Date()) ?? Date())],
        workspaces: [ProjectWorkspace(name: "Example App", bundleIdentifier: "com.example.app", environment: "staging", selectedCertificateID: nil, selectedProfileID: nil, notes: "")],
        artifacts: [ArtifactRecord(name: "Example Ad Hoc.mobileprovision", kind: .profile, detail: "Ready")],
        audit: [AuditEvent(message: "Preview vault created")]
    )
}

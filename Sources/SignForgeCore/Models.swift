import Foundation

enum SigningAssetKind: String, CaseIterable, Codable, Identifiable {
    case apiCredential = "API credential"
    case privateKey = "Private key"
    case csr = "CSR"
    case certificate = "Certificate"
    case bundleID = "Bundle ID"
    case device = "Device"
    case profile = "Provisioning profile"
    case p12 = "P12"
    case ipa = "IPA"
    var id: String { rawValue }
}

enum CertificateType: String, CaseIterable, Codable, Identifiable {
    case development = "Development"
    case distribution = "Distribution"
    case appleDevelopment = "Apple Development"
    case appleDistribution = "Apple Distribution"
    var id: String { rawValue }
}

enum ProfileType: String, CaseIterable, Codable, Identifiable {
    case development = "Development"
    case adHoc = "Ad Hoc"
    case appStore = "App Store"
    case enterprise = "Enterprise"
    var id: String { rawValue }
}

struct AppleCredential: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var issuerID: String
    var keyID: String
    var teamID: String
    var p8KeyPreview: String
    var createdAt = Date()
}

struct SigningKey: Identifiable, Codable, Hashable {
    var id = UUID()
    var label: String
    var algorithm: String
    var fingerprint: String
    var exportable: Bool
    var createdAt = Date()
}

struct CertificateRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: CertificateType
    var serialNumber: String
    var fingerprint: String
    var expiresAt: Date
    var matchingKeyID: UUID?
}

struct BundleIDRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var identifier: String
    var name: String
    var capabilities: [String]
}

struct DeviceRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var udid: String
    var platform: String
    var enabled: Bool
}

struct ProvisioningProfileRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var uuid: String
    var type: ProfileType
    var bundleIdentifier: String
    var certificateFingerprints: [String]
    var deviceUDIDs: [String]
    var entitlements: [String: String]
    var expiresAt: Date
}

struct ProjectWorkspace: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var bundleIdentifier: String
    var environment: String
    var selectedCertificateID: UUID?
    var selectedProfileID: UUID?
    var notes: String
}

struct ArtifactRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var kind: SigningAssetKind
    var detail: String
    var createdAt = Date()
}

struct AuditEvent: Identifiable, Codable, Hashable {
    var id = UUID()
    var message: String
    var createdAt = Date()
}

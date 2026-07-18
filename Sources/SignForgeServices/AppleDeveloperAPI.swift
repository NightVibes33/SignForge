import Foundation

protocol AppleDeveloperAPI {
    func healthCheck(credential: AppleCredential) async throws
    func createCertificate(type: CertificateType, csrPEM: String, credential: AppleCredential) async throws -> CertificateRecord
    func listBundleIDs(credential: AppleCredential) async throws -> [BundleIDRecord]
    func registerDevice(name: String, udid: String, platform: String, credential: AppleCredential) async throws -> DeviceRecord
    func createProfile(name: String, type: ProfileType, bundleID: BundleIDRecord, certificates: [CertificateRecord], devices: [DeviceRecord], credential: AppleCredential) async throws -> ProvisioningProfileRecord
}

struct AppStoreConnectClient: AppleDeveloperAPI {
    var baseURL = URL(string: "https://api.appstoreconnect.apple.com/v1")!

    func healthCheck(credential: AppleCredential) async throws {}

    func createCertificate(type: CertificateType, csrPEM: String, credential: AppleCredential) async throws -> CertificateRecord {
        CertificateRecord(name: type.rawValue, type: type, serialNumber: "pending-api", fingerprint: "pending-api", expiresAt: Date().addingTimeInterval(60 * 60 * 24 * 365), matchingKeyID: nil)
    }

    func listBundleIDs(credential: AppleCredential) async throws -> [BundleIDRecord] { [] }

    func registerDevice(name: String, udid: String, platform: String, credential: AppleCredential) async throws -> DeviceRecord {
        DeviceRecord(name: name, udid: udid, platform: platform, enabled: true)
    }

    func createProfile(name: String, type: ProfileType, bundleID: BundleIDRecord, certificates: [CertificateRecord], devices: [DeviceRecord], credential: AppleCredential) async throws -> ProvisioningProfileRecord {
        ProvisioningProfileRecord(name: name, uuid: UUID().uuidString, type: type, bundleIdentifier: bundleID.identifier, certificateFingerprints: certificates.map(\.fingerprint), deviceUDIDs: devices.map(\.udid), entitlements: [:], expiresAt: Date().addingTimeInterval(60 * 60 * 24 * 365))
    }
}

import Foundation
import CryptoKit

protocol AppleDeveloperAPI {
    func healthCheck(credential: AppleCredential, privateKeyPEM: String) async throws
    func createCertificate(type: CertificateType, csrPEM: String, credential: AppleCredential, privateKeyPEM: String) async throws -> CertificateRecord
    func listBundleIDs(credential: AppleCredential, privateKeyPEM: String) async throws -> [BundleIDRecord]
    func createBundleID(name: String, identifier: String, credential: AppleCredential, privateKeyPEM: String) async throws -> BundleIDRecord
    func registerDevice(name: String, udid: String, platform: String, credential: AppleCredential, privateKeyPEM: String) async throws -> DeviceRecord
    func createProfile(name: String, type: ProfileType, bundleID: BundleIDRecord, certificates: [CertificateRecord], devices: [DeviceRecord], credential: AppleCredential, privateKeyPEM: String) async throws -> ProvisioningProfileRecord
}

struct AppStoreConnectClient: AppleDeveloperAPI {
    var baseURL = URL(string: "https://api.appstoreconnect.apple.com/v1/")!
    var session: URLSession = .shared
    var jwt = AppStoreConnectJWT()

    func healthCheck(credential: AppleCredential, privateKeyPEM: String) async throws {
        let request = try authedRequest(path: "bundleIds?limit=1", method: "GET", credential: credential, privateKeyPEM: privateKeyPEM)
        _ = try await session.data(for: request)
    }

    func createCertificate(type: CertificateType, csrPEM: String, credential: AppleCredential, privateKeyPEM: String) async throws -> CertificateRecord {
        let body: [String: Any] = ["data": ["type": "certificates", "attributes": ["certificateType": type.apiValue, "csrContent": csrPEM]]]
        let request = try authedRequest(path: "certificates", method: "POST", credential: credential, privateKeyPEM: privateKeyPEM, body: body)
        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode(CertificateCreateResponse.self, from: data)
        return CertificateRecord(name: type.rawValue, type: type, remoteID: decoded.data.id, serialNumber: decoded.data.attributes.serialNumber ?? decoded.data.id, fingerprint: decoded.data.attributes.certificateContent.sha256Fingerprint, certificatePEM: decoded.data.attributes.certificateContent.pemCertificate, expiresAt: decoded.data.attributes.expirationDate ?? Date(), matchingKeyID: nil)
    }

    func listBundleIDs(credential: AppleCredential, privateKeyPEM: String) async throws -> [BundleIDRecord] {
        let request = try authedRequest(path: "bundleIds?limit=200", method: "GET", credential: credential, privateKeyPEM: privateKeyPEM)
        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode(BundleIDListResponse.self, from: data)
        return decoded.data.map { BundleIDRecord(remoteID: $0.id, identifier: $0.attributes.identifier, name: $0.attributes.name, capabilities: []) }
    }

    func createBundleID(name: String, identifier: String, credential: AppleCredential, privateKeyPEM: String) async throws -> BundleIDRecord {
        let body: [String: Any] = ["data": ["type": "bundleIds", "attributes": ["name": name, "identifier": identifier, "platform": "IOS"]]]
        let request = try authedRequest(path: "bundleIds", method: "POST", credential: credential, privateKeyPEM: privateKeyPEM, body: body)
        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode(BundleIDCreateResponse.self, from: data)
        return BundleIDRecord(remoteID: decoded.data.id, identifier: decoded.data.attributes.identifier, name: decoded.data.attributes.name, capabilities: [])
    }

    func registerDevice(name: String, udid: String, platform: String, credential: AppleCredential, privateKeyPEM: String) async throws -> DeviceRecord {
        let body: [String: Any] = ["data": ["type": "devices", "attributes": ["name": name, "udid": udid, "platform": platform.apiDevicePlatform]]]
        let request = try authedRequest(path: "devices", method: "POST", credential: credential, privateKeyPEM: privateKeyPEM, body: body)
        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode(DeviceCreateResponse.self, from: data)
        return DeviceRecord(remoteID: decoded.data.id, name: decoded.data.attributes.name, udid: decoded.data.attributes.udid, platform: decoded.data.attributes.platform, enabled: decoded.data.attributes.status != "DISABLED")
    }

    func createProfile(name: String, type: ProfileType, bundleID: BundleIDRecord, certificates: [CertificateRecord], devices: [DeviceRecord], credential: AppleCredential, privateKeyPEM: String) async throws -> ProvisioningProfileRecord {
        let certRefs = certificates.compactMap { cert in cert.remoteID }.map { remoteID in ["type": "certificates", "id": remoteID] }
        let deviceRefs = devices.compactMap { device in device.remoteID }.map { remoteID in ["type": "devices", "id": remoteID] }
        let relationships: [String: Any] = ["bundleId": ["data": ["type": "bundleIds", "id": bundleID.remoteID ?? bundleID.identifier]], "certificates": ["data": certRefs], "devices": ["data": deviceRefs]]
        let body: [String: Any] = ["data": ["type": "profiles", "attributes": ["name": name, "profileType": type.apiValue], "relationships": relationships]]
        let request = try authedRequest(path: "profiles", method: "POST", credential: credential, privateKeyPEM: privateKeyPEM, body: body)
        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder.signForge.decode(ProfileCreateResponse.self, from: data)
        return ProvisioningProfileRecord(remoteID: decoded.data.id, name: decoded.data.attributes.name, uuid: decoded.data.attributes.uuid, type: type, bundleIdentifier: bundleID.identifier, certificateFingerprints: certificates.map(\.fingerprint), deviceUDIDs: devices.map(\.udid), entitlements: [:], expiresAt: decoded.data.attributes.expirationDate)
    }

    private func authedRequest(path: String, method: String, credential: AppleCredential, privateKeyPEM: String, body: [String: Any]? = nil) throws -> URLRequest {
        let token = try jwt.makeToken(issuerID: credential.issuerID, keyID: credential.keyID, privateKeyPEM: privateKeyPEM)
        guard let url = URL(string: path, relativeTo: baseURL) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        return request
    }
}

private extension CertificateType { var apiValue: String { self == .appleDistribution ? "DISTRIBUTION" : "DEVELOPMENT" } }
private extension ProfileType { var apiValue: String { [ProfileType.development: "IOS_APP_DEVELOPMENT", .adHoc: "IOS_APP_ADHOC", .appStore: "IOS_APP_STORE", .enterprise: "IOS_APP_INHOUSE"][self] ?? "IOS_APP_DEVELOPMENT" } }
private extension String {
    var apiDevicePlatform: String { lowercased().contains("mac") ? "MAC_OS" : "IOS" }
    var sha256Fingerprint: String { Data(utf8).sha256Fingerprint }
    var pemCertificate: String { contains("BEGIN CERTIFICATE") ? self : "-----BEGIN CERTIFICATE-----\n" + self.chunked(every: 64).joined(separator: "\n") + "\n-----END CERTIFICATE-----" }
    func chunked(every size: Int) -> [String] { stride(from: 0, to: count, by: size).map { index in let start = self.index(startIndex, offsetBy: index); let end = self.index(start, offsetBy: Swift.min(size, distance(from: start, to: endIndex))); return String(self[start..<end]) } }
}
private extension Data { var sha256Fingerprint: String { SHA256.hash(data: self).map { String(format: "%02X", $0) }.joined(separator: ":") } }

struct CertificateCreateResponse: Decodable { let data: CertificateResource }
struct CertificateResource: Decodable { let id: String; let attributes: CertificateAttributes }
struct CertificateAttributes: Decodable { let certificateContent: String; let serialNumber: String?; let expirationDate: Date? }
struct BundleIDListResponse: Decodable { let data: [BundleIDResource] }
struct BundleIDCreateResponse: Decodable { let data: BundleIDResource }
struct BundleIDResource: Decodable { let id: String; let attributes: BundleIDAttributes }
struct BundleIDAttributes: Decodable { let identifier: String; let name: String }
struct DeviceCreateResponse: Decodable { let data: DeviceResource }
struct DeviceResource: Decodable { let id: String; let attributes: DeviceAttributes }
struct DeviceAttributes: Decodable { let name: String; let udid: String; let platform: String; let status: String }
struct ProfileCreateResponse: Decodable { let data: ProfileResource }
struct ProfileResource: Decodable { let id: String; let attributes: ProfileAttributes }
struct ProfileAttributes: Decodable { let name: String; let uuid: String; let expirationDate: Date; let profileContent: String? }

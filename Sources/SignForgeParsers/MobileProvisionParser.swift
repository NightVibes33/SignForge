import Foundation

struct MobileProvisionParser {
    func parse(data: Data, fallbackName: String) -> ProvisioningProfileRecord {
        let plistData = extractPlist(from: data) ?? data
        if let object = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil), let plist = object as? [String: Any] {
            let name = plist["Name"] as? String ?? fallbackName
            let uuid = plist["UUID"] as? String ?? UUID().uuidString
            let expires = plist["ExpirationDate"] as? Date ?? Date()
            let entitlements = plist["Entitlements"] as? [String: Any] ?? [:]
            let appID = entitlements["application-identifier"] as? String ?? "unknown.bundle"
            let bundle = appID.split(separator: ".", maxSplits: 1).dropFirst().first.map(String.init) ?? appID
            let devices = plist["ProvisionedDevices"] as? [String] ?? []
            let profileType: ProfileType = devices.isEmpty ? .appStore : .development
            let stringEntitlements = entitlements.reduce(into: [String: String]()) { result, item in result[item.key] = String(describing: item.value) }
            return ProvisioningProfileRecord(name: name, uuid: uuid, type: profileType, bundleIdentifier: bundle, certificateFingerprints: [], deviceUDIDs: devices, entitlements: stringEntitlements, expiresAt: expires)
        }
        return regexFallback(data: data, fallbackName: fallbackName)
    }

    private func extractPlist(from data: Data) -> Data? {
        let text = String(decoding: data, as: UTF8.self)
        guard let start = text.range(of: "<?xml"), let end = text.range(of: "</plist>") else { return nil }
        let xml = text[start.lowerBound..<end.upperBound]
        return Data(String(xml).utf8)
    }

    private func regexFallback(data: Data, fallbackName: String) -> ProvisioningProfileRecord {
        let text = String(decoding: data, as: UTF8.self)
        let uuid = firstMatch("<key>UUID</key>\\s*<string>([^<]+)</string>", in: text) ?? UUID().uuidString
        let name = firstMatch("<key>Name</key>\\s*<string>([^<]+)</string>", in: text) ?? fallbackName
        let appID = firstMatch("<key>application-identifier</key>\\s*<string>([^<]+)</string>", in: text) ?? "unknown.bundle"
        let bundle = appID.split(separator: ".", maxSplits: 1).dropFirst().first.map(String.init) ?? appID
        return ProvisioningProfileRecord(name: name, uuid: uuid, type: .development, bundleIdentifier: bundle, certificateFingerprints: [], deviceUDIDs: [], entitlements: ["application-identifier": appID], expiresAt: Date())
    }

    private func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}

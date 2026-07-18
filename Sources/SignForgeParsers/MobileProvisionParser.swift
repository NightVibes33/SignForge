import Foundation

struct MobileProvisionParser {
    func parse(data: Data, fallbackName: String) -> ProvisioningProfileRecord {
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

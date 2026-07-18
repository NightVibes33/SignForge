import Foundation

struct EntitlementDifference: Identifiable, Hashable {
    enum Kind: String { case missingInApp = "Missing in app"; case missingInProfile = "Missing in profile"; case different = "Different" }
    var id = UUID()
    var key: String
    var kind: Kind
    var appValue: String
    var profileValue: String
}

struct EntitlementsDiff {
    func compare(app: [String: String], profile: [String: String]) -> [EntitlementDifference] {
        let keys = Set(app.keys).union(profile.keys).sorted()
        return keys.compactMap { key in
            let appValue = app[key]
            let profileValue = profile[key]
            if appValue == nil { return EntitlementDifference(key: key, kind: .missingInApp, appValue: "", profileValue: profileValue ?? "") }
            if profileValue == nil { return EntitlementDifference(key: key, kind: .missingInProfile, appValue: appValue ?? "", profileValue: "") }
            if appValue != profileValue { return EntitlementDifference(key: key, kind: .different, appValue: appValue ?? "", profileValue: profileValue ?? "") }
            return nil
        }
    }

    func parsePlistString(_ text: String) -> [String: String] {
        guard let data = text.data(using: .utf8), let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil), let dict = object as? [String: Any] else { return [:] }
        return dict.reduce(into: [String: String]()) { result, item in result[item.key] = String(describing: item.value) }
    }
}

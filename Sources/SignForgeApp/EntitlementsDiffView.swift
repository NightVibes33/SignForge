import SwiftUI

struct EntitlementsDiffView: View {
    @Environment(VaultStore.self) private var store
    @State private var appEntitlements = ""
    private let diff = EntitlementsDiff()

    var differences: [EntitlementDifference] {
        let app = diff.parsePlistString(appEntitlements)
        let profile = store.state.profiles.first?.entitlements ?? [:]
        return diff.compare(app: app, profile: profile)
    }

    var body: some View {
        Form {
            Section("App entitlements plist") {
                TextEditor(text: $appEntitlements).frame(minHeight: 140)
            }
            Section("Profile") {
                Text(store.state.profiles.first?.name ?? "No profile loaded").foregroundStyle(.secondary)
            }
            Section("Differences") {
                if differences.isEmpty { Text("No differences").foregroundStyle(.secondary) }
                ForEach(differences) { item in
                    VStack(alignment: .leading) {
                        Text(item.key)
                        Text(item.kind.rawValue).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.navigationTitle("Entitlements")
    }
}

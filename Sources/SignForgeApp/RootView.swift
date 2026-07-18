import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case credentials = "Apple credentials"
    case keys = "Keys and CSRs"
    case certificates = "Certificates"
    case bundles = "Bundle IDs"
    case devices = "Devices"
    case profiles = "Profiles"
    case p12 = "P12 builder"
    case signer = "IPA signer"
    case vault = "Artifact vault"
    case diagnostics = "Diagnostics"
    case security = "Security"
    var id: String { rawValue }
}

struct RootView: View {
    @Environment(VaultStore.self) private var store
    @State private var selection: AppSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Text(section.rawValue).tag(section as AppSection?)
            }
            .navigationTitle("SignForge")
        } detail: {
            switch selection ?? .dashboard {
            case .dashboard: DashboardView()
            case .credentials: CredentialView()
            case .keys: KeysCSRView()
            case .certificates: InventoryView(title: "Certificates", rows: store.state.certificates.map { $0.name }, empty: "No certificates")
            case .bundles: InventoryView(title: "Bundle IDs", rows: store.state.bundleIDs.map { $0.identifier }, empty: "No bundle IDs")
            case .devices: InventoryView(title: "Devices", rows: store.state.devices.map { "\($0.name) - \($0.udid)" }, empty: "No devices")
            case .profiles: InventoryView(title: "Profiles", rows: store.state.profiles.map { $0.name }, empty: "No profiles")
            case .p12: BuilderView(kind: .p12)
            case .signer: BuilderView(kind: .ipa)
            case .vault: ArtifactVaultView()
            case .diagnostics: DiagnosticsView()
            case .security: SecuritySettingsView()
            }
        }
    }
}

struct DashboardView: View {
    @Environment(VaultStore.self) private var store
    private let validator = ValidationEngine()

    var body: some View {
        List {
            Section("Vault") {
                MetricRow(label: "Credentials", value: store.state.credentials.count)
                MetricRow(label: "Certificates", value: store.state.certificates.count)
                MetricRow(label: "Profiles", value: store.state.profiles.count)
                MetricRow(label: "Artifacts", value: store.state.artifacts.count)
            }
            Section("Workspaces") {
                ForEach(store.state.workspaces) { workspace in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(workspace.name).font(.headline)
                        Text(workspace.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                        ForEach(validator.findings(for: workspace, state: store.state)) { finding in
                            Label(finding.title, systemImage: finding.severity == .ready ? "checkmark.seal" : "exclamationmark.triangle")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("Dashboard")
    }
}

struct MetricRow: View {
    var label: String
    var value: Int
    var body: some View { HStack { Text(label); Spacer(); Text(value, format: .number).foregroundStyle(.secondary) } }
}

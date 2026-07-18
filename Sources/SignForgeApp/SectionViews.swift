import SwiftUI

struct CredentialView: View {
    @Environment(VaultStore.self) private var store
    @State private var name = "Apple developer team"
    @State private var issuerID = ""
    @State private var keyID = ""
    @State private var teamID = ""

    var body: some View {
        Form {
            Section("App Store Connect API") {
                TextField("Name", text: $name)
                TextField("Issuer ID", text: $issuerID)
                TextField("Key ID", text: $keyID)
                TextField("Team ID", text: $teamID)
                Button("Save credential") {
                    store.state.credentials.insert(AppleCredential(name: name, issuerID: issuerID, keyID: keyID, teamID: teamID, p8KeyPreview: "Imported .p8 required"), at: 0)
                    store.state.audit.insert(AuditEvent(message: "Saved Apple credential \(name)"), at: 0)
                    store.save()
                }
            }
            Section("Saved") { ForEach(store.state.credentials) { Text($0.name) } }
        }
        .navigationTitle("Credentials")
    }
}

struct KeysCSRView: View {
    @Environment(VaultStore.self) private var store
    @State private var commonName = "Apple Distribution"
    @State private var organization = "Developer Team"
    @State private var country = "US"
    private let crypto = SigningCrypto()

    var body: some View {
        Form {
            Section("Keys") {
                Button("Generate exportable key") {
                    let key = crypto.generateSoftwareKey(label: "Signing key \(store.state.keys.count + 1)")
                    store.state.keys.insert(key, at: 0)
                    store.addArtifact(ArtifactRecord(name: key.label, kind: .privateKey, detail: key.fingerprint))
                }
                ForEach(store.state.keys) { key in
                    VStack(alignment: .leading) { Text(key.label); Text(key.fingerprint).font(.caption).foregroundStyle(.secondary) }
                }
            }
            Section("CSR") {
                TextField("Common name", text: $commonName)
                TextField("Organization", text: $organization)
                TextField("Country", text: $country)
                Button("Generate CSR artifact") {
                    guard let key = store.state.keys.first else { return }
                    let csr = crypto.generateCSR(commonName: commonName, organization: organization, country: country, key: key)
                    store.addArtifact(ArtifactRecord(name: "\(commonName).csr", kind: .csr, detail: String(csr.prefix(80)) + "..."))
                }
            }
        }
        .navigationTitle("Keys and CSRs")
    }
}

struct InventoryView: View {
    var title: String
    var rows: [String]
    var empty: String
    var body: some View {
        List { if rows.isEmpty { Text(empty).foregroundStyle(.secondary) } else { ForEach(rows, id: \.self) { Text($0) } } }
            .navigationTitle(title)
    }
}

struct BuilderView: View {
    @Environment(VaultStore.self) private var store
    var kind: SigningAssetKind
    var body: some View {
        Form {
            Section(kind == .p12 ? "P12 export" : "IPA resign") {
                Text(kind == .p12 ? "Select a matching certificate and exportable private key before exporting." : "Import an unsigned IPA, select a profile, then re-sign.")
                    .foregroundStyle(.secondary)
                Button(kind == .p12 ? "Create P12 task" : "Create signing task") {
                    store.addArtifact(ArtifactRecord(name: kind == .p12 ? "Signing identity.p12" : "Signed app.ipa", kind: kind, detail: "Pending hardened export implementation"))
                }
            }
        }
        .navigationTitle(kind.rawValue)
    }
}

struct ArtifactVaultView: View {
    @Environment(VaultStore.self) private var store
    var body: some View {
        List(store.state.artifacts) { artifact in
            VStack(alignment: .leading) { Text(artifact.name); Text("\(artifact.kind.rawValue) - \(artifact.detail)").font(.caption).foregroundStyle(.secondary) }
        }
        .navigationTitle("Artifact vault")
    }
}

struct DiagnosticsView: View {
    @Environment(VaultStore.self) private var store
    var body: some View {
        List(store.state.audit) { event in
            VStack(alignment: .leading) { Text(event.message); Text(event.createdAt, style: .date).font(.caption).foregroundStyle(.secondary) }
        }
        .navigationTitle("Diagnostics")
    }
}

struct SecuritySettingsView: View {
    var body: some View {
        Form {
            Section("Vault security") {
                Label("Keychain-backed vault boundary", systemImage: "key")
                Label("Face ID app lock planned", systemImage: "faceid")
                Label("Clipboard auto-clear planned", systemImage: "clipboard")
            }
        }
        .navigationTitle("Security")
    }
}

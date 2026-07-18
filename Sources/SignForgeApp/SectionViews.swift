import SwiftUI
import UniformTypeIdentifiers

struct CredentialView: View {
    @Environment(VaultStore.self) private var store
    @State private var name = "Apple developer team"
    @State private var issuerID = ""
    @State private var keyID = ""
    @State private var teamID = ""
    @State private var p8 = ""
    @State private var status = ""
    private let keychain = KeychainVault()

    var body: some View {
        Form {
            Section("App Store Connect API") {
                TextField("Name", text: $name)
                TextField("Issuer ID", text: $issuerID)
                TextField("Key ID", text: $keyID)
                TextField("Team ID", text: $teamID)
                TextEditor(text: $p8).frame(minHeight: 120)
                Button("Save credential") { saveCredential() }
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
            Section("Saved") {
                ForEach(store.state.credentials) { credential in
                    VStack(alignment: .leading) {
                        Text(credential.name)
                        Text("Team \(credential.teamID) - key \(credential.keyID)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.navigationTitle("Credentials")
    }

    private func saveCredential() {
        let credential = AppleCredential(name: name, issuerID: issuerID, keyID: keyID, teamID: teamID, p8KeyPreview: String(p8.prefix(32)))
        do {
            try keychain.saveString(p8, account: credential.id.uuidString + ".p8")
            store.state.credentials.insert(credential, at: 0)
            store.state.audit.insert(AuditEvent(message: "Saved Apple credential \(name)"), at: 0)
            store.save()
            status = "Saved to Keychain"
        } catch { status = error.localizedDescription }
    }
}

struct KeysCSRView: View {
    @Environment(VaultStore.self) private var store
    @State private var commonName = "Apple Distribution"
    @State private var organization = "Developer Team"
    @State private var country = "US"
    @State private var exportPackage: ExportPackage?
    @State private var isExporting = false
    private let crypto = SigningCrypto()
    private let workflow = ArtifactWorkflow()

    var body: some View {
        Form {
            Section("Keys") {
                Button("Generate exportable key") { generateKey() }
                ForEach(store.state.keys) { key in
                    VStack(alignment: .leading) {
                        Text(key.label)
                        Text(key.fingerprint).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("CSR") {
                TextField("Common name", text: $commonName)
                TextField("Organization", text: $organization)
                TextField("Country", text: $country)
                Button("Generate CSR") { generateCSR() }
            }
        }
        .navigationTitle("Keys and CSRs")
        .fileExporter(isPresented: $isExporting, document: ArtifactDocument(text: exportPackage?.payload.exportText ?? ""), contentType: .plainText, defaultFilename: exportPackage?.filename ?? "artifact.txt") { _ in }
    }

    private func generateKey() {
        do {
            let key = try crypto.generateSoftwareKey(label: "Signing key \(store.state.keys.count + 1)")
            store.state.keys.insert(key, at: 0)
            store.addArtifact(ArtifactRecord(name: key.label, kind: .privateKey, detail: key.fingerprint))
        } catch {
            store.state.audit.insert(AuditEvent(message: error.localizedDescription), at: 0)
            store.save()
        }
    }

    private func generateCSR() {
        guard let key = store.state.keys.first else { return }
        let result = workflow.makeCSR(commonName: commonName, organization: organization, country: country, key: key)
        store.addArtifact(result.0)
        exportPackage = result.1
        isExporting = true
    }
}

struct ProfilesView: View {
    @Environment(VaultStore.self) private var store
    @State private var importing = false
    @State private var profileName = "Development profile"
    @State private var profileType: ProfileType = .development
    @State private var status = ""
    private let workflow = ArtifactWorkflow()
    private let api = AppStoreConnectClient()
    private let keychain = KeychainVault()

    var body: some View {
        List {
            Section("Create profile") {
                TextField("Name", text: $profileName)
                Picker("Type", selection: $profileType) { ForEach(ProfileType.allCases) { Text($0.rawValue).tag($0) } }
                Button("Create with Apple") { Task { await createProfile() } }
                Button("Import .mobileprovision") { importing = true }
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
            Section("Profiles") {
                ForEach(store.state.profiles) { profile in
                    VStack(alignment: .leading) {
                        Text(profile.name)
                        Text("\(profile.bundleIdentifier) - \(profile.uuid)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Profiles")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in importProfile(result) }
    }

    private func createProfile() async {
        guard let credential = store.state.credentials.first else { status = "Missing credential"; return }
        guard let p8 = try? keychain.loadString(account: credential.id.uuidString + ".p8"), let p8 else { status = "Missing .p8 in Keychain"; return }
        guard let bundle = store.state.bundleIDs.first else { status = "Create or refresh a bundle ID first"; return }
        guard !store.state.certificates.isEmpty else { status = "Create a certificate first"; return }
        do {
            let profile = try await api.createProfile(name: profileName, type: profileType, bundleID: bundle, certificates: store.state.certificates, devices: store.state.devices, credential: credential, privateKeyPEM: p8)
            store.state.profiles.insert(profile, at: 0)
            store.addArtifact(ArtifactRecord(name: profile.name + ".mobileprovision", kind: .profile, detail: profile.uuid))
            status = "Created"
        } catch { status = error.localizedDescription }
    }

    private func importProfile(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let profile = workflow.importMobileProvision(data: data, filename: url.lastPathComponent)
        store.state.profiles.insert(profile, at: 0)
        store.addArtifact(ArtifactRecord(name: url.lastPathComponent, kind: .profile, detail: profile.uuid))
    }
}

struct InventoryView: View {
    var title: String
    var rows: [String]
    var empty: String
    var body: some View {
        List {
            if rows.isEmpty { Text(empty).foregroundStyle(.secondary) }
            ForEach(rows, id: \.self) { row in Text(row) }
        }.navigationTitle(title)
    }
}

struct ArtifactVaultView: View {
    @Environment(VaultStore.self) private var store
    var body: some View { List(store.state.artifacts) { artifact in VStack(alignment: .leading) { Text(artifact.name); Text("\(artifact.kind.rawValue) - \(artifact.detail)").font(.caption).foregroundStyle(.secondary) } }.navigationTitle("Artifact vault") }
}

struct DiagnosticsView: View {
    @Environment(VaultStore.self) private var store
    var body: some View { List(store.state.audit) { event in VStack(alignment: .leading) { Text(event.message); Text(event.createdAt, style: .date).font(.caption).foregroundStyle(.secondary) } }.navigationTitle("Diagnostics") }
}

struct SecuritySettingsView: View {
    var body: some View { Form { Section("Vault security") { Label("API keys stored in Keychain", systemImage: "key"); Label("Protected file vault", systemImage: "lock.doc"); Label("Local-only artifact generation", systemImage: "iphone") } }.navigationTitle("Security") }
}

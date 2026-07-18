import SwiftUI

struct CertificatesView: View {
    @Environment(VaultStore.self) private var store
    @State private var selectedType: CertificateType = .appleDistribution
    @State private var status = ""
    private let api = AppStoreConnectClient()
    private let keychain = KeychainVault()

    var body: some View {
        Form {
            Section("Create from latest CSR") {
                Picker("Type", selection: $selectedType) { ForEach(CertificateType.allCases) { Text($0.rawValue).tag($0) } }
                Button("Create certificate with Apple") { Task { await createCertificate() } }
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
            Section("Certificates") {
                ForEach(store.state.certificates) { cert in
                    VStack(alignment: .leading) {
                        Text(cert.name)
                        Text("\(cert.fingerprint) - expires \(cert.expiresAt.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.navigationTitle("Certificates")
    }

    private func createCertificate() async {
        guard let credential = store.state.credentials.first else { status = "Missing credential"; return }
        guard let p8 = try? keychain.loadString(account: credential.id.uuidString + ".p8"), let p8 else { status = "Missing .p8 in Keychain"; return }
        let csr = store.state.artifacts.first { $0.kind == .csr }?.detail ?? ""
        do {
            let cert = try await api.createCertificate(type: selectedType, csrPEM: csr, credential: credential, privateKeyPEM: p8)
            store.state.certificates.insert(cert, at: 0)
            store.addArtifact(ArtifactRecord(name: cert.name + ".cer", kind: .certificate, detail: cert.fingerprint))
            status = "Certificate created"
        } catch { status = error.localizedDescription }
    }
}

struct BundleIDsView: View {
    @Environment(VaultStore.self) private var store
    @State private var status = ""
    private let api = AppStoreConnectClient()
    private let keychain = KeychainVault()

    var body: some View {
        List {
            Section { Button("Refresh from Apple") { Task { await refresh() } }; if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) } }
            Section("Bundle IDs") { ForEach(store.state.bundleIDs) { Text($0.identifier) } }
        }.navigationTitle("Bundle IDs")
    }

    private func refresh() async {
        guard let credential = store.state.credentials.first else { status = "Missing credential"; return }
        guard let p8 = try? keychain.loadString(account: credential.id.uuidString + ".p8"), let p8 else { status = "Missing .p8 in Keychain"; return }
        do { store.state.bundleIDs = try await api.listBundleIDs(credential: credential, privateKeyPEM: p8); store.save(); status = "Updated" } catch { status = error.localizedDescription }
    }
}

struct DevicesView: View {
    @Environment(VaultStore.self) private var store
    @State private var name = "Developer iPhone"
    @State private var udid = ""
    @State private var platform = "iOS"
    @State private var status = ""
    private let api = AppStoreConnectClient()
    private let keychain = KeychainVault()

    var body: some View {
        Form {
            Section("Register device") {
                TextField("Name", text: $name)
                TextField("UDID", text: $udid)
                Picker("Platform", selection: $platform) { Text("iOS").tag("iOS"); Text("macOS").tag("macOS") }
                Button("Register with Apple") { Task { await register() } }
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
            Section("Devices") { ForEach(store.state.devices) { Text("\($0.name) - \($0.udid)") } }
        }.navigationTitle("Devices")
    }

    private func register() async {
        guard let credential = store.state.credentials.first else { status = "Missing credential"; return }
        guard let p8 = try? keychain.loadString(account: credential.id.uuidString + ".p8"), let p8 else { status = "Missing .p8 in Keychain"; return }
        do { let device = try await api.registerDevice(name: name, udid: udid, platform: platform, credential: credential, privateKeyPEM: p8); store.state.devices.insert(device, at: 0); store.save(); status = "Registered" } catch { status = error.localizedDescription }
    }
}

import SwiftUI
import UniformTypeIdentifiers

struct P12BuilderView: View {
    @Environment(VaultStore.self) private var store
    @State private var certificatePEM = ""
    @State private var password = ""
    @State private var selectedKeyID: UUID?
    @State private var output = Data()
    @State private var exporting = false
    @State private var status = ""
    private let crypto = SigningCrypto()
    private let helper = SigningHelperClient()

    var body: some View {
        Form {
            Section("Certificate") {
                TextEditor(text: $certificatePEM).frame(minHeight: 140)
            }
            Section("Private key") {
                Picker("Key", selection: $selectedKeyID) {
                    Text("Latest key").tag(UUID?.none)
                    ForEach(store.state.keys) { key in Text(key.label).tag(Optional(key.id)) }
                }
                SecureField("P12 password", text: $password)
                Button("Export .p12") { Task { await exportP12() } }
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
            Section("Available keys") {
                ForEach(store.state.keys) { key in
                    VStack(alignment: .leading) {
                        Text(key.label)
                        Text(key.fingerprint).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("P12 builder")
        .fileExporter(isPresented: $exporting, document: BinaryArtifactDocument(data: output), contentType: .data, defaultFilename: "identity.p12") { result in
            if case .success = result { status = "Exported identity.p12" }
        }
    }

    private func exportP12() async {
        guard !certificatePEM.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { status = "Paste certificate PEM first"; return }
        guard !password.isEmpty else { status = "Password required"; return }
        let key = selectedKeyID.flatMap { id in store.state.keys.first { $0.id == id } } ?? store.state.keys.first
        guard let key else { status = "Generate a key first"; return }
        do {
            let privateKeyPEM = try crypto.exportPrivateKeyPEM(key: key)
            output = try await helper.exportP12(certificatePEM: certificatePEM, privateKeyPEM: privateKeyPEM, password: password)
            store.addArtifact(ArtifactRecord(name: "identity.p12", kind: .p12, detail: key.fingerprint))
            exporting = true
            status = "P12 ready"
        } catch { status = error.localizedDescription }
    }
}

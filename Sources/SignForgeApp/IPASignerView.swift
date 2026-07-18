import SwiftUI
import UniformTypeIdentifiers

struct IPASignerView: View {
    enum ImportKind { case ipa, p12, profile }

    @Environment(VaultStore.self) private var store
    @State private var importKind: ImportKind?
    @State private var importing = false
    @State private var ipa = Data()
    @State private var p12 = Data()
    @State private var profile = Data()
    @State private var password = ""
    @State private var entitlements = ""
    @State private var signedIPA = Data()
    @State private var exporting = false
    @State private var status = ""
    private let helper = SigningHelperClient()

    var body: some View {
        Form {
            Section("Inputs") {
                Button(ipa.isEmpty ? "Import IPA" : "IPA imported") { beginImport(.ipa) }
                Button(p12.isEmpty ? "Import P12" : "P12 imported") { beginImport(.p12) }
                Button(profile.isEmpty ? "Import mobileprovision" : "Profile imported") { beginImport(.profile) }
                SecureField("P12 password", text: $password)
            }
            Section("Entitlements") {
                TextEditor(text: $entitlements).frame(minHeight: 120)
            }
            Section("Sign") {
                Button("Sign IPA") { Task { await sign() } }
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("IPA signer")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in handleImport(result) }
        .fileExporter(isPresented: $exporting, document: BinaryArtifactDocument(data: signedIPA), contentType: .data, defaultFilename: "signed.ipa") { result in
            if case .success = result { status = "Exported signed.ipa" }
        }
    }

    private func beginImport(_ kind: ImportKind) {
        importKind = kind
        importing = true
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let kind = importKind else { return }
        switch kind {
        case .ipa: ipa = data; status = "IPA imported"
        case .p12: p12 = data; status = "P12 imported"
        case .profile:
            profile = data
            let parsed = MobileProvisionParser().parse(data: data, fallbackName: url.lastPathComponent)
            store.state.profiles.insert(parsed, at: 0)
            store.addArtifact(ArtifactRecord(name: url.lastPathComponent, kind: .profile, detail: parsed.uuid))
            status = "Profile imported"
        }
    }

    private func sign() async {
        guard !ipa.isEmpty else { status = "Import an IPA first"; return }
        guard !p12.isEmpty else { status = "Import a P12 first"; return }
        guard !profile.isEmpty else { status = "Import a profile first"; return }
        guard !password.isEmpty else { status = "P12 password required"; return }
        do {
            signedIPA = try await helper.resignIPA(ipaBase64: ipa.base64EncodedString(), p12Base64: p12.base64EncodedString(), p12Password: password, mobileProvisionBase64: profile.base64EncodedString(), entitlementsPlist: entitlements.isEmpty ? nil : entitlements)
            store.addArtifact(ArtifactRecord(name: "signed.ipa", kind: .ipa, detail: "Signed by helper"))
            exporting = true
            status = "Signed IPA ready"
        } catch { status = error.localizedDescription }
    }
}

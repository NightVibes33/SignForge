import AuthenticationServices
import SwiftUI
import UniformTypeIdentifiers

struct WorkstationView: View {
    @Environment(VaultStore.self) private var store
    @State private var selectedStep: SigningStep = .connect

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HeroPanel(selectedStep: $selectedStep)
                    StepRail(selectedStep: $selectedStep)
                    selectedSurface
                    ArtifactShelf()
                }
                .padding(18)
            }
            .background(AppBackground())
            .navigationTitle("SignForge")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var selectedSurface: some View {
        switch selectedStep {
        case .connect: ConnectSurface()
        case .p12: P12MakerSurface()
        case .profile: ProfileMakerSurface()
        case .ipa: IPASignerSurface()
        case .vault: VaultSurface()
        }
    }
}

enum SigningStep: String, CaseIterable, Identifiable {
    case connect = "Connect"
    case p12 = "P12"
    case profile = "Profile"
    case ipa = "IPA"
    case vault = "Vault"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .connect: return "Connect Apple"
        case .p12: return "Make .p12"
        case .profile: return "Make profile"
        case .ipa: return "Sign IPA"
        case .vault: return "Artifacts"
        }
    }
    var subtitle: String {
        switch self {
        case .connect: return "API key"
        case .p12: return "Helper export"
        case .profile: return "Provisioning"
        case .ipa: return "Optional signing"
        case .vault: return "Outputs"
        }
    }
    var icon: String {
        switch self {
        case .connect: return "person.crop.circle.badge.checkmark"
        case .p12: return "key.viewfinder"
        case .profile: return "doc.badge.gearshape"
        case .ipa: return "iphone.gen3"
        case .vault: return "shippingbox"
        }
    }
}

struct AppBackground: View {
    var body: some View {
Color(uiColor: .systemBackground).ignoresSafeArea()
    }
}

struct HeroPanel: View {
    @Environment(VaultStore.self) private var store
    @Binding var selectedStep: SigningStep

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apple signing studio")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Create Apple signing assets from iOS. Sign in with Apple can identify the user in signed builds; App Store Connect API keys perform cert and profile operations.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Image(systemName: "seal.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.mint)
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            HStack(spacing: 10) {
                StatPill(title: "Keys", value: store.state.keys.count, tint: .mint)
                StatPill(title: "Certs", value: store.state.certificates.count, tint: .cyan)
                StatPill(title: "Profiles", value: store.state.profiles.count, tint: .orange)
            }
            Button { selectedStep = .p12 } label: {
                Label("Start signing asset flow", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.primary.opacity(0.08)))
    }
}

struct StepRail: View {
    @Binding var selectedStep: SigningStep

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SigningStep.allCases) { step in
                    Button { selectedStep = step } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Image(systemName: step.icon).font(.headline)
                            Text(step.title).font(.subheadline.weight(.semibold))
                            Text(step.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(width: 126, alignment: .leading)
                        .padding(14)
                        .background(selectedStep == step ? Color.mint.opacity(0.16) : Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(selectedStep == step ? Color.mint.opacity(0.7) : Color.primary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
            }
        }
    }
}

struct StatPill: View {
    var title: String
    var value: Int
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value, format: .number).font(.title3.weight(.bold)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SurfaceCard<Content: View>: View {
    var title: String
    var subtitle: String
    var icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title3.weight(.semibold)).foregroundStyle(.mint)
                    .frame(width: 42, height: 42)
                    .background(Color.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.title3.weight(.bold)).foregroundStyle(.primary)
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.primary.opacity(0.08)))
    }
}

struct ConnectSurface: View {
    @Environment(VaultStore.self) private var store
    @State private var name = ""
    @State private var issuerID = ""
    @State private var keyID = ""
    @State private var teamID = ""
    @State private var p8 = ""
    @State private var status = ""
    private let keychain = KeychainVault()

    var body: some View {
        SurfaceCard(title: "Connect App Store Connect", subtitle: "Sign in with Apple identifies the user when the app is signed with the Apple Sign In capability. API keys still power cert and profile creation.", icon: "key.fill") {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                switch result {
                case .success: status = "Apple identity linked"
                case .failure(let error): status = "Sign in with Apple requires a signed build with the Apple Sign In capability: " + error.localizedDescription
                }
            }
            .frame(height: 48)
            StatusLine(text: "Unsigned IPAs cannot use Sign in with Apple. Sign this app with a profile that includes Apple Sign In to avoid AuthorizationError 1000.")
            CredentialFields(name: $name, issuerID: $issuerID, keyID: $keyID, teamID: $teamID, p8: $p8)
            Button { saveCredential() } label: { Label("Save API key", systemImage: "key.fill") }.buttonStyle(PrimaryButtonStyle())
            Link(destination: URL(string: "https://appstoreconnect.apple.com/access/integrations/api")!) {
                Label("Open App Store Connect API keys", systemImage: "safari")
                    .font(.footnote.weight(.semibold))
            }
            StatusLine(text: status.isEmpty ? readyText : status)
        }
    }

    private var readyText: String { store.state.credentials.isEmpty ? "No API key saved yet" : "API key saved. Signing flows are ready." }

    private func saveCredential() {
        let credential = AppleCredential(name: name, issuerID: issuerID, keyID: keyID, teamID: teamID, p8KeyPreview: String(p8.prefix(32)))
        do {
            try keychain.saveString(p8, account: credential.id.uuidString + ".p8")
            store.state.credentials.insert(credential, at: 0)
            store.state.audit.insert(AuditEvent(message: "Saved Apple credential \(name)"), at: 0)
            store.save()
            status = "API key saved securely"
        } catch { status = error.localizedDescription }
    }
}

struct CredentialFields: View {
    @Binding var name: String
    @Binding var issuerID: String
    @Binding var keyID: String
    @Binding var teamID: String
    @Binding var p8: String

    var body: some View {
        VStack(spacing: 10) {
            DarkField("Credential name", text: $name)
            DarkField("Issuer ID", text: $issuerID)
            HStack(spacing: 10) {
                DarkField("Key ID", text: $keyID)
                DarkField("Team ID", text: $teamID)
            }
            TextEditor(text: $p8)
                .scrollContentBackground(.hidden)
                .foregroundStyle(.primary)
                .frame(minHeight: 116)
                .padding(10)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if p8.isEmpty { Text("Paste .p8 private key").foregroundStyle(.secondary).padding(16) }
                }
        }
    }
}

struct P12MakerSurface: View {
    @Environment(VaultStore.self) private var store
    @State private var commonName = ""
    @State private var organization = ""
    @State private var country = "US"
    @State private var certificatePEM = ""
    @State private var password = ""
    @State private var selectedKeyID: UUID?
    @State private var output = Data()
    @State private var exporting = false
    @State private var status = "Generate a key and CSR on iOS, create the Apple certificate, then export a password-protected .p12 through the helper bridge."
    private let crypto = SigningCrypto()
    private let workflow = ArtifactWorkflow()
    private let helper = SigningHelperClient()

    var body: some View {
        SurfaceCard(title: "Password-protected .p12 maker", subtitle: "Private key plus Apple certificate. iOS owns the key; final P12 export uses the helper bridge when needed.", icon: "key.viewfinder") {
            FlowChecklist(items: [
                ("API key", !store.state.credentials.isEmpty),
                ("Private key", !store.state.keys.isEmpty),
                ("Certificate", !certificatePEM.isEmpty || store.state.certificates.first?.certificatePEM != nil),
                ("Password", !password.isEmpty)
            ])
            DarkField("Common name", text: $commonName)
            HStack(spacing: 10) {
                DarkField("Organization", text: $organization)
                DarkField("Country", text: $country)
            }
            SecureDarkField("P12 password", text: $password)
            TextEditor(text: $certificatePEM)
                .scrollContentBackground(.hidden)
                .foregroundStyle(.primary)
                .frame(minHeight: 110)
                .padding(10)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) { if certificatePEM.isEmpty { Text("Certificate PEM auto-fills from latest cert, or paste it here").foregroundStyle(.secondary).padding(16) } }
            HStack(spacing: 10) {
                Button("Generate key") { generateKey() }.buttonStyle(SecondaryButtonStyle())
                Button("Export CSR") { exportCSR() }.buttonStyle(SecondaryButtonStyle())
            }
            Button { Task { await exportP12() } } label: { Label("Export password-protected .p12", systemImage: "square.and.arrow.up.fill") }.buttonStyle(PrimaryButtonStyle())
            StatusLine(text: status)
        }
        .fileExporter(isPresented: $exporting, document: BinaryArtifactDocument(data: output), contentType: .data, defaultFilename: "SignForge-identity.p12") { result in
            if case .success = result { status = "Exported SignForge-identity.p12" }
        }
    }

    private func generateKey() {
        do {
            let key = try crypto.generateSoftwareKey(label: "Signing key \(store.state.keys.count + 1)")
            store.state.keys.insert(key, at: 0)
            store.addArtifact(ArtifactRecord(name: key.label, kind: .privateKey, detail: key.fingerprint))
            selectedKeyID = key.id
            status = "Private key generated in Keychain"
        } catch { status = error.localizedDescription }
    }

    private func exportCSR() {
        guard let key = selectedKeyID.flatMap({ id in store.state.keys.first { $0.id == id } }) ?? store.state.keys.first else { status = "Generate a key first"; return }
        let result = workflow.makeCSR(commonName: commonName, organization: organization, country: country, key: key)
        store.addArtifact(result.0)
        output = Data(result.1.payload.exportText.utf8)
        exporting = true
        status = "CSR exported. Use it to create the Apple certificate."
    }

    private func exportP12() async {
        let pem = certificatePEM.isEmpty ? (store.state.certificates.first?.certificatePEM ?? "") : certificatePEM
        guard !pem.isEmpty else { status = "Create or paste an Apple certificate first"; return }
        guard !password.isEmpty else { status = "Enter a P12 password"; return }
        guard let key = selectedKeyID.flatMap({ id in store.state.keys.first { $0.id == id } }) ?? store.state.keys.first else { status = "Generate a key first"; return }
        do {
            let privateKeyPEM = try crypto.exportPrivateKeyPEM(key: key)
            output = try await helper.exportP12(certificatePEM: pem, privateKeyPEM: privateKeyPEM, password: password)
            store.addArtifact(ArtifactRecord(name: "SignForge-identity.p12", kind: .p12, detail: key.fingerprint))
            exporting = true
            status = "P12 ready"
        } catch { status = error.localizedDescription }
    }
}

struct ProfileMakerSurface: View {
    @Environment(VaultStore.self) private var store
    @State private var bundleName = ""
    @State private var bundleID = ""
    @State private var deviceName = ""
    @State private var udid = ""
    @State private var profileName = "Development profile"
    @State private var profileType: ProfileType = .development
    @State private var output = Data()
    @State private var exporting = false
    @State private var status = "Create a bundle ID, register devices if needed, then create and export a .mobileprovision."
    private let api = AppStoreConnectClient()
    private let keychain = KeychainVault()

    var body: some View {
        SurfaceCard(title: ".mobileprovision maker", subtitle: "Create Apple provisioning profiles from iOS using App Store Connect API access.", icon: "doc.badge.gearshape") {
            FlowChecklist(items: [
                ("API key", !store.state.credentials.isEmpty),
                ("Bundle ID", !store.state.bundleIDs.isEmpty),
                ("Certificate", !store.state.certificates.isEmpty),
                ("Profile", !store.state.profiles.isEmpty)
            ])
            DarkField("Bundle name", text: $bundleName)
            DarkField("Bundle identifier", text: $bundleID)
            Button("Create bundle ID") { Task { await createBundle() } }.buttonStyle(SecondaryButtonStyle())
            HStack(spacing: 10) {
                DarkField("Device name", text: $deviceName)
                DarkField("UDID", text: $udid)
            }
            Button("Register device") { Task { await registerDevice() } }.buttonStyle(SecondaryButtonStyle())
            DarkField("Profile name", text: $profileName)
            Picker("Type", selection: $profileType) {
                ForEach(ProfileType.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Button { Task { await createProfile() } } label: { Label("Create .mobileprovision", systemImage: "doc.badge.plus") }.buttonStyle(PrimaryButtonStyle())
            StatusLine(text: status)
        }
        .fileExporter(isPresented: $exporting, document: BinaryArtifactDocument(data: output), contentType: .data, defaultFilename: "SignForge.mobileprovision") { result in
            if case .success = result { status = "Exported SignForge.mobileprovision" }
        }
    }

    private func authMaterial() -> (AppleCredential, String)? {
        guard let credential = store.state.credentials.first else { status = "Save an API key first"; return nil }
        guard let p8 = (try? keychain.loadString(account: credential.id.uuidString + ".p8")) ?? nil else { status = "Missing .p8 in Keychain"; return nil }
        return (credential, p8)
    }

    private func createBundle() async {
        guard let auth = authMaterial() else { return }
        do {
            let bundle = try await api.createBundleID(name: bundleName, identifier: bundleID, credential: auth.0, privateKeyPEM: auth.1)
            store.state.bundleIDs.insert(bundle, at: 0)
            store.save()
            status = "Bundle ID created"
        } catch { status = error.localizedDescription }
    }

    private func registerDevice() async {
        guard !udid.isEmpty else { status = "Enter a device UDID"; return }
        guard let auth = authMaterial() else { return }
        do {
            let device = try await api.registerDevice(name: deviceName, udid: udid, platform: "iOS", credential: auth.0, privateKeyPEM: auth.1)
            store.state.devices.insert(device, at: 0)
            store.save()
            status = "Device registered"
        } catch { status = error.localizedDescription }
    }

    private func createProfile() async {
        guard let auth = authMaterial() else { return }
        guard let bundle = store.state.bundleIDs.first else { status = "Create a bundle ID first"; return }
        guard !store.state.certificates.isEmpty else { status = "Create a certificate first"; return }
        do {
            let profile = try await api.createProfile(name: profileName, type: profileType, bundleID: bundle, certificates: store.state.certificates, devices: store.state.devices, credential: auth.0, privateKeyPEM: auth.1)
            store.state.profiles.insert(profile, at: 0)
            store.addArtifact(ArtifactRecord(name: profile.name + ".mobileprovision", kind: .profile, detail: profile.uuid))
            output = Data(profile.uuid.utf8)
            exporting = true
            status = "Profile record created. Export requires Apple profile content when returned or a downloaded/imported .mobileprovision."
        } catch { status = error.localizedDescription }
    }
}

struct IPASignerSurface: View {
    var body: some View {
        SurfaceCard(title: "Optional IPA signer", subtitle: "Optional iOS front end for helper-backed signing. Real IPA code signing requires the macOS helper.", icon: "iphone.gen3") {
            IPASignerView()
                .frame(minHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

struct VaultSurface: View {
    @Environment(VaultStore.self) private var store
    var body: some View {
        SurfaceCard(title: "Artifact vault", subtitle: "Generated and imported signing artifacts, with clear labels for on-device outputs and helper outputs.", icon: "shippingbox") {
            if store.state.artifacts.isEmpty {
                StatusLine(text: "No artifacts yet")
            } else {
                VStack(spacing: 10) {
                    ForEach(store.state.artifacts.prefix(8)) { artifact in
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: artifact.kind)).foregroundStyle(.mint).frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(artifact.name).foregroundStyle(.primary).font(.subheadline.weight(.semibold))
                                Text(artifact.kind.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    private func icon(for kind: SigningAssetKind) -> String {
        switch kind {
        case .p12, .privateKey: return "key.fill"
        case .profile: return "doc.fill"
        case .ipa: return "iphone"
        case .certificate: return "seal.fill"
        default: return "shippingbox.fill"
        }
    }
}

struct ArtifactShelf: View {
    @Environment(VaultStore.self) private var store
    var body: some View {
        HStack(spacing: 10) {
            MiniMetric(icon: "key.fill", label: ".p12", count: store.state.artifacts.filter { $0.kind == .p12 }.count)
            MiniMetric(icon: "doc.fill", label: "profiles", count: store.state.profiles.count)
            MiniMetric(icon: "iphone", label: "IPAs", count: store.state.artifacts.filter { $0.kind == .ipa }.count)
        }
    }
}

struct MiniMetric: View {
    var icon: String
    var label: String
    var count: Int
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.mint)
            VStack(alignment: .leading, spacing: 1) {
                Text(count, format: .number).font(.headline.weight(.bold)).foregroundStyle(.primary)
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct FlowChecklist: View {
    var items: [(String, Bool)]
    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack {
                    Image(systemName: item.1 ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.1 ? .mint : .secondary)
                    Text(item.0).foregroundStyle(.primary)
                    Spacer()
                }
                .font(.subheadline.weight(.medium))
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct StatusLine: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct DarkField: View {
    var placeholder: String
    @Binding var text: String
    init(_ placeholder: String, text: Binding<String>) { self.placeholder = placeholder; self._text = text }
    var body: some View {
        TextField(placeholder, text: $text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(13)
            .foregroundStyle(.primary)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.08)))
    }
}

struct SecureDarkField: View {
    var placeholder: String
    @Binding var text: String
    init(_ placeholder: String, text: Binding<String>) { self.placeholder = placeholder; self._text = text }
    var body: some View {
        SecureField(placeholder, text: $text)
            .padding(13)
            .foregroundStyle(.primary)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.08)))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .tertiarySystemGroupedBackground).opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.08)))
    }
}

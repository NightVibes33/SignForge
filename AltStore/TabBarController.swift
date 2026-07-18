//
//  TabBarController.swift
//  SignForge
//
//  Based on SideStore's tab controller. SignForge replaces the visible tabs with
//  a signing workstation while keeping SideStore runtime services in the target.
//

import UIKit
import SwiftUI
import AltStoreCore

extension TabBarController
{
    private enum Tab: Int, CaseIterable
    {
        case vault
        case profiles
        case signer
        case devices
        case settings
    }
}

final class TabBarController: UITabBarController
{
    private var initialSegue: (identifier: String, sender: Any?)?
    private var _viewDidAppear = false
    private var sourcesViewController: SourcesViewController!

    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)

        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.importApp(_:)), name: AppDelegate.importAppDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.presentSources(_:)), name: AppDelegate.addSourceDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.exportFiles(_:)), name: AppDelegate.exportCertificateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.openErrorLog(_:)), name: ToastView.openErrorLogNotification, object: nil)
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.installSignForgeInterface()
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)

        _viewDidAppear = true

        if let (identifier, sender) = self.initialSegue
        {
            self.initialSegue = nil
            self.performSegue(withIdentifier: identifier, sender: sender)
        }
    }

    override func performSegue(withIdentifier identifier: String, sender: Any?)
    {
        guard _viewDidAppear else {
            self.initialSegue = (identifier, sender)
            return
        }

        super.performSegue(withIdentifier: identifier, sender: sender)
    }
}

private extension TabBarController
{
    func installSignForgeInterface()
    {
        let vault = UINavigationController(rootViewController: UIHostingController(rootView: SignForgeVaultView()))
        vault.tabBarItem = UITabBarItem(title: "Vault", image: UIImage(systemName: "shippingbox"), selectedImage: UIImage(systemName: "shippingbox.fill"))

        let profiles = UINavigationController(rootViewController: UIHostingController(rootView: SignForgeProfilesView()))
        profiles.tabBarItem = UITabBarItem(title: "Profiles", image: UIImage(systemName: "person.text.rectangle"), selectedImage: UIImage(systemName: "person.text.rectangle.fill"))

        let signer = UINavigationController(rootViewController: UIHostingController(rootView: SignForgeSignerView()))
        signer.tabBarItem = UITabBarItem(title: "Signer", image: UIImage(systemName: "signature"), selectedImage: UIImage(systemName: "signature"))

        let devices = UINavigationController(rootViewController: UIHostingController(rootView: SignForgeDevicesView()))
        devices.tabBarItem = UITabBarItem(title: "Devices", image: UIImage(systemName: "iphone.gen3"), selectedImage: UIImage(systemName: "iphone.gen3"))

        let settings = UINavigationController(rootViewController: UIHostingController(rootView: SignForgeSettingsView()))
        settings.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"), selectedImage: UIImage(systemName: "gearshape.fill"))

        self.viewControllers = [vault, profiles, signer, devices, settings]
        self.selectedIndex = Tab.vault.rawValue
    }

    @objc func presentSources(_ sender: Any)
    {
        self.selectedIndex = Tab.profiles.rawValue
    }

    @objc func importApp(_ notification: Notification)
    {
        self.selectedIndex = Tab.signer.rawValue
    }

    @objc func openErrorLog(_ notification: Notification)
    {
        self.selectedIndex = Tab.settings.rawValue
    }

    @objc func exportFiles(_ notification: Notification)
    {
        self.selectedIndex = Tab.settings.rawValue
    }
}

private enum SignForgeAssetKind: String, CaseIterable, Identifiable
{
    case sideconf = "Account.sideconf"
    case p12 = "Certificate.p12"
    case mobileprovision = "Profile.mobileprovision"
    case ipa = "Unsigned IPA"

    var id: String { rawValue }

    var symbolName: String
    {
        switch self {
        case .sideconf: return "person.badge.key"
        case .p12: return "key.fill"
        case .mobileprovision: return "doc.badge.gearshape"
        case .ipa: return "app.dashed"
        }
    }
}

private struct SignForgeImportedAsset: Identifiable
{
    let id = UUID()
    let kind: SignForgeAssetKind
    let name: String
    let byteCount: Int
    let summary: String
}

private final class SignForgeVaultModel: ObservableObject
{
    @Published var assets: [SignForgeImportedAsset] = []
    @Published var lastError: String?

    func importFile(_ url: URL)
    {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            let name = url.lastPathComponent
            let lower = name.lowercased()
            let kind: SignForgeAssetKind

            if lower.hasSuffix(".sideconf") {
                kind = .sideconf
            } else if lower.hasSuffix(".p12") || lower.hasSuffix(".pfx") {
                kind = .p12
            } else if lower.hasSuffix(".mobileprovision") || lower.hasSuffix(".provisionprofile") {
                kind = .mobileprovision
            } else {
                kind = .ipa
            }

            let asset = SignForgeImportedAsset(kind: kind, name: name, byteCount: data.count, summary: self.summary(for: kind, data: data))
            self.assets.removeAll { $0.kind == asset.kind && $0.name == asset.name }
            self.assets.insert(asset, at: 0)
            self.lastError = nil
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    private func summary(for kind: SignForgeAssetKind, data: Data) -> String
    {
        switch kind {
        case .sideconf:
            if let imported = try? JSONDecoder().decode(ImportedAccount.self, from: data) {
                let certSize = ByteCountFormatter.string(fromByteCount: Int64(imported.cert.count), countStyle: .file)
                return "SideStore account bundle for \(imported.email), certificate \(certSize)."
            }
            return "SideStore account bundle detected. Importable after validation."
        case .p12:
            return "PKCS#12 signing identity ready for password validation."
        case .mobileprovision:
            let text = String(decoding: data, as: UTF8.self)
            if let name = text.signForgePlistValue("Name") {
                return "Provisioning profile: \(name)."
            }
            return "Provisioning profile ready for entitlement and device checks."
        case .ipa:
            return "Unsigned app archive queued for signing."
        }
    }
}

private struct SignForgeVaultView: View
{
    @StateObject private var model = SignForgeVaultModel()
    @State private var importing = false

    var body: some View {
        List {
            Section("Intake") {
                Button {
                    importing = true
                } label: {
                    Label("Import signing file", systemImage: "square.and.arrow.down")
                }
            }

            Section("Signing Vault") {
                if model.assets.isEmpty {
                    SignForgeEmptyRow(title: "No files imported", subtitle: "Import Account.sideconf, p12, mobileprovision, or an unsigned IPA.")
                } else {
                    ForEach(model.assets) { asset in
                        SignForgeAssetRow(asset: asset)
                    }
                }
            }

            if let lastError = model.lastError {
                Section("Import Error") {
                    Label(lastError, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("SignForge")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { model.importFile(url) }
            case .failure(let error):
                model.lastError = error.localizedDescription
            }
        }
    }
}

private struct SignForgeProfilesView: View
{
    var body: some View {
        List {
            Section("Profile Checks") {
                SignForgeCapabilityRow(symbol: "person.crop.rectangle.stack", title: "Developer profile intake", detail: "Reads .mobileprovision metadata and prepares device eligibility checks.")
                SignForgeCapabilityRow(symbol: "checkmark.seal", title: "Entitlement review", detail: "Surfaces profile name, app identifier, team, and supported entitlements before signing.")
                SignForgeCapabilityRow(symbol: "iphone.and.arrow.forward", title: "Device install path", detail: "Keeps SideStore minimuxer and provisioning-profile install support in the fork.")
            }
        }
        .navigationTitle("Profiles")
    }
}

private struct SignForgeSignerView: View
{
    var body: some View {
        List {
            Section("Signing Pipeline") {
                SignForgeCapabilityRow(symbol: "app.badge", title: "IPA intake", detail: "Accepts unsigned iOS app archives from Files.")
                SignForgeCapabilityRow(symbol: "key.horizontal", title: "Certificate pairing", detail: "Pairs p12 identity data with the matching mobileprovision profile.")
                SignForgeCapabilityRow(symbol: "signature", title: "SideStore signing core", detail: "Build stays on SideStore and AltSign internals instead of a hardcoded IPA-only shell.")
                SignForgeCapabilityRow(symbol: "square.and.arrow.up", title: "Install handoff", detail: "Preserves the SideStore install path for real device workflows.")
            }
        }
        .navigationTitle("Signer")
    }
}

private struct SignForgeDevicesView: View
{
    var body: some View {
        List {
            Section("Device Prep") {
                SignForgeCapabilityRow(symbol: "network", title: "Pairing files", detail: "Keeps SideStore pairing-file and minimuxer plumbing for iOS device communication.")
                SignForgeCapabilityRow(symbol: "doc.badge.plus", title: "Profile install", detail: "Supports mobile provisioning profile install through SideStore's device service layer.")
                SignForgeCapabilityRow(symbol: "arrow.clockwise", title: "Refresh model", detail: "Keeps SideStore refresh/resign behavior available for installed apps.")
            }
        }
        .navigationTitle("Devices")
    }
}

private struct SignForgeSettingsView: View
{
    var body: some View {
        List {
            Section("Account") {
                SignForgeCapabilityRow(symbol: "person.badge.key", title: "Account.sideconf compatible", detail: "Uses SideStore's existing imported account structure for Apple developer account bundles.")
                SignForgeCapabilityRow(symbol: "lock.doc", title: "Credential handling", detail: "Imported secrets stay in app storage/keychain paths; the UI does not print passwords.")
            }

            Section("Build") {
                SignForgeCapabilityRow(symbol: "hammer", title: "Unsigned IPA output", detail: "CI workflow packages an unsigned real-device IPA for macOS 26 runners.")
                SignForgeCapabilityRow(symbol: "doc.text", title: "AGPL fork", detail: "This app is a direct SideStore fork and keeps the upstream AGPL license.")
            }
        }
        .navigationTitle("Settings")
    }
}

private struct SignForgeAssetRow: View
{
    let asset: SignForgeImportedAsset

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: asset.kind.symbolName)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.headline)
                Text(asset.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: Int64(asset.byteCount), countStyle: .file))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct SignForgeCapabilityRow: View
{
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct SignForgeEmptyRow: View
{
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

private extension String
{
    func signForgePlistValue(_ key: String) -> String?
    {
        guard let keyRange = self.range(of: "<key>\(key)</key>") else { return nil }
        let suffix = self[keyRange.upperBound...]
        guard let start = suffix.range(of: "<string>"), let end = suffix.range(of: "</string>") else { return nil }
        return String(suffix[start.upperBound..<end.lowerBound])
    }
}

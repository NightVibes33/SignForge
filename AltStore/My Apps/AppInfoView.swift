//
//  AppInfoView.swift
//  AltStore
//
//  Created by Magesh K on 2/7/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import AltStoreCore
import AltSign

struct AppInfoView: View {
    let installedApp: InstalledApp
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isShowingToast: Bool = false
    @State private var toastMessage: String = ""
    
    private var appBundleURL: URL {
        if installedApp.resignedBundleIdentifier == Bundle.main.bundleIdentifier {
            return Bundle.main.bundleURL
        } else {
            return installedApp.fileURL
        }
    }
    
    private var provisioningProfile: ALTProvisioningProfile? {
        let profileURL = appBundleURL.appendingPathComponent("embedded.mobileprovision")
        return ALTProvisioningProfile(url: profileURL)
    }
    
    private var infoPlist: [String: Any]? {
        let plistURL = appBundleURL.appendingPathComponent("Info.plist")
        return NSDictionary(contentsOf: plistURL) as? [String: Any]
    }
    
    var body: some View {
        NavigationView {
            List {
                // Header
                Section {
                    HStack(spacing: 16) {
                        AppIconView(installedApp: installedApp)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(installedApp.name)
                                .font(.headline)
                            Text(installedApp.bundleIdentifier)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if installedApp.resignedBundleIdentifier != installedApp.bundleIdentifier {
                                Text("Resigned: \(installedApp.resignedBundleIdentifier)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Metadata Section
                Section(header: Text("General Metadata")) {
                    InfoRow(label: "Status", value: installedApp.isActive ? "Active" : "Inactive", valueColor: installedApp.isActive ? .green : .red)
                    InfoRow(label: "Version", value: installedApp.localizedVersion)
                    if let team = installedApp.team {
                        InfoRow(label: "Team Name", value: team.name)
                        InfoRow(label: "Team ID", value: team.identifier)
                    }
                    InfoRow(label: "Expiration Date", value: formatDate(provisioningProfile?.expirationDate ?? installedApp.expirationDate))
                    InfoRow(label: "Refreshed Date", value: formatDate(provisioningProfile?.creationDate ?? installedApp.refreshedDate))
                    InfoRow(label: "Installed Date", value: formatDate(installedApp.installedDate))
                    if let serialNumber = installedApp.certificateSerialNumber {
                        InfoRow(label: "Certificate Serial", value: serialNumber)
                    }
                    InfoRow(label: "Needs Resign", value: installedApp.needsResign ? "Yes" : "No")
                    InfoRow(label: "Uses Main Profile", value: installedApp.useMainProfile ? "Yes" : "No")
                }
                
                // Provisioning Profile Section
                if let profile = provisioningProfile {
                    Section(header: Text("Provisioning Profile")) {
                        NavigationLink(destination: ProvisioningProfileDetailView(profile: profile)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name)
                                    .font(.subheadline)
                                Text("UUID: \(profile.UUID.uuidString)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Info.plist Section
                if let plist = infoPlist {
                    Section(header: Text("Info.plist")) {
                        NavigationLink(destination: InfoPlistContainerView(plist: plist)) {
                            Text("View Info.plist (\(plist.count) keys)")
                        }
                    }
                }
                
                // App Extensions Section
                if !installedApp.appExtensions.isEmpty {
                    Section(header: Text("App Extensions")) {
                        ForEach(Array(installedApp.appExtensions), id: \.bundleIdentifier) { ext in
                            NavigationLink(destination: ExtensionInfoView(appExtension: ext, parentAppURL: appBundleURL)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ext.name)
                                        .font(.subheadline)
                                    Text(ext.bundleIdentifier)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("App Details")
            .navigationBarItems(trailing: SwiftUI.Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
            .overlay(
                AppInfoToastView(isShowing: $isShowingToast, message: toastMessage)
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Provisioning Profile Detail View

struct ProvisioningProfileDetailView: View {
    let profile: ALTProvisioningProfile
    @State private var isShowingToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        List {
            Section(header: Text("Profile Metadata")) {
                InfoRow(label: "Name", value: profile.name)
                InfoRow(label: "UUID", value: profile.UUID.uuidString)
                if let identifier = profile.identifier {
                    InfoRow(label: "Identifier", value: identifier)
                }
                InfoRow(label: "Team Name", value: profile.teamName)
                InfoRow(label: "Team Identifier", value: profile.teamIdentifier)
                InfoRow(label: "App Bundle ID", value: profile.bundleIdentifier)
                InfoRow(label: "Created", value: formatDate(profile.creationDate))
                InfoRow(label: "Expires", value: formatDate(profile.expirationDate))
                InfoRow(label: "Free Developer Profile", value: profile.isFreeProvisioningProfile ? "Yes" : "No")
            }
            
            if !profile.certificates.isEmpty {
                Section(header: Text("Developer Certificates (\(profile.certificates.count))")) {
                    ForEach(profile.certificates, id: \.serialNumber) { cert in
                        NavigationLink(destination: CertificateDetailView(certificate: cert)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cert.name)
                                    .font(.subheadline)
                                Text("Serial: \(cert.serialNumber)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            if !profile.deviceIDs.isEmpty {
                Section(header: Text("Provisioned Devices (\(profile.deviceIDs.count))")) {
                    NavigationLink(destination: DeviceIDsView(devices: profile.deviceIDs)) {
                        Text("View Provisioned Devices")
                    }
                }
            }
            
            Section(header: Text("Entitlements (\(profile.entitlements.count))")) {
                let sortedEntitlements = profile.entitlements.sorted { $0.key.rawValue < $1.key.rawValue }
                ForEach(sortedEntitlements, id: \.key.rawValue) { entitlement, value in
                    EntitlementRow(key: entitlement.rawValue, value: value, onCopy: {
                        UIPasteboard.general.string = "\(value)"
                        toastMessage = "Copied \(entitlement.rawValue)!"
                        withAnimation {
                            isShowingToast = true
                        }
                    })
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationTitle("Profile Details")
        .overlay(
            AppInfoToastView(isShowing: $isShowingToast, message: toastMessage)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}



// MARK: - Helper Views

struct AppIconView: View {
    let installedApp: InstalledApp
    @State private var image: UIImage? = nil
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.gray.opacity(0.15)
                    .overlay(
                        Image(systemName: "app")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    )
            }
        }
        .frame(width: 60, height: 60)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .onAppear {
            installedApp.loadIcon { result in
                if case .success(let img) = result {
                    DispatchQueue.main.async {
                        self.image = img
                    }
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct EntitlementRow: View {
    let key: String
    let value: Any
    let onCopy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(key)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .bold()
                Spacer()
                SwiftUI.Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            Text(formatValue(value))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatValue(_ val: Any) -> String {
        if let array = val as? [Any] {
            return "[" + array.map { "\($0)" }.joined(separator: ", ") + "]"
        }
        if let dict = val as? [String: Any] {
            return "{" + dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ") + "}"
        }
        return "\(val)"
    }
}

// MARK: - Device IDs View

struct DeviceIDsView: View {
    let devices: [String]
    
    var body: some View {
        List(devices, id: \.self) { udid in
            HStack {
                Text(udid)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                SwiftUI.Button(action: {
                    UIPasteboard.general.string = udid
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .navigationTitle("Device IDs")
    }
}

// MARK: - Extension Info View

struct ExtensionInfoView: View {
    let appExtension: InstalledExtension
    let parentAppURL: URL
    
    private var extensionURL: URL {
        parentAppURL.appendingPathComponent("PlugIns").appendingPathComponent("\(appExtension.name).appex")
    }
    
    private var provisioningProfile: ALTProvisioningProfile? {
        let profileURL = extensionURL.appendingPathComponent("embedded.mobileprovision")
        return ALTProvisioningProfile(url: profileURL)
    }
    
    private var infoPlist: [String: Any]? {
        let plistURL = extensionURL.appendingPathComponent("Info.plist")
        return NSDictionary(contentsOf: plistURL) as? [String: Any]
    }
    
    var body: some View {
        List {
            Section(header: Text("Extension Metadata")) {
                InfoRow(label: "Name", value: appExtension.name)
                InfoRow(label: "Bundle Identifier", value: appExtension.bundleIdentifier)
                if appExtension.resignedBundleIdentifier != appExtension.bundleIdentifier {
                    InfoRow(label: "Resigned Bundle ID", value: appExtension.resignedBundleIdentifier)
                }
            }
            
            if let profile = provisioningProfile {
                Section(header: Text("Extension Provisioning Profile")) {
                    NavigationLink(destination: ProvisioningProfileDetailView(profile: profile)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.subheadline)
                            Text("Expires: \(formatDate(profile.expirationDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if let plist = infoPlist {
                Section(header: Text("Extension Info.plist")) {
                    NavigationLink(destination: InfoPlistContainerView(plist: plist)) {
                        Text("View Info.plist (\(plist.count) keys)")
                    }
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationTitle(appExtension.name)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Toast View

struct AppInfoToastView: View {
    @Binding var isShowing: Bool
    let message: String
    
    var body: some View {
        VStack {
            Spacer()
            if isShowing {
                Text(message)
                    .font(.subheadline)
                    .padding()
                    .background(Color.black.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .transition(.slide)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                self.isShowing = false
                            }
                        }
                    }
            }
        }
        .padding(.bottom, 50)
    }
}

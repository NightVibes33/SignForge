//
//  CertificatesView.swift
//  AltStore
//
//  Created by Magesh K on 2026-06-29.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import AltSign
import UniformTypeIdentifiers

struct CertificatesView: View {
    weak var presentingViewController: UIViewController?
    
    private var allowedImportTypes: [UTType] {
        let extensions = ["p12", "pfx", "pkcs12", "der", "cer", "crt", "pem"]
        return extensions.compactMap { UTType(filenameExtension: $0) }
    }
    
    private var allowedKeyImportTypes: [UTType] {
        let extensions = ["key", "pem", "der"]
        return extensions.compactMap { UTType(filenameExtension: $0) }
    }
    
    @StateObject private var viewModel = CertificatesViewModel()
    
    @State private var showCreateDialog = false
    @State private var showFileImporter = false
    @State private var showPasswordInputForImport = false
    @State private var showRevokeConfirmation = false
    @State private var showDeactivateConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showExportPasswordPrompt = false
    @State private var hasInitialLoaded = false
    @State private var hasCopiedActiveSerialNumber = false
    
    @State private var newMachineName = ""
    @State private var exportPasswordInput = ""
    @State private var certificateToExport: ALTCertificate? = nil
    @State private var certificateToRevoke: ALTCertificate? = nil
    @State private var certificateToDelete: ALTCertificate? = nil
    
    enum SortOption: String, CaseIterable, Identifiable {
        case creationDate = "Creation Date"
        case expiryDate = "Expiry Date"
        case name = "Name"
        case keys = "Keys"
        
        var id: String { self.rawValue }
    }
    
    enum GroupOption: String, CaseIterable, Identifiable {
        case none = "None"
        case creationDate = "Creation Date"
        case expiryDate = "Expiry Date"
        case name = "Name"
        case keys = "Keys"
        
        var id: String { self.rawValue }
    }
    
    @State private var currentSort: SortOption = .creationDate
    @State private var isAscending: Bool = false
    @State private var currentGroup: GroupOption = .none
    @State private var showKeyImporter = false
    @State private var keyTextImportItem: KeyTextImportItem? = nil
    @State private var privateKeyTextInput = ""
    @State private var certificateToAddKeyFor: ALTCertificate? = nil
    @State private var showClearKeyConfirmation = false
    @State private var certificateToClearKeyFor: ALTCertificate? = nil
    
    struct KeyTextImportItem: Identifiable {
        let id: String
        let cert: ALTCertificate
    }
    
    struct GroupedCertificates: Identifiable {
        var id: String { name }
        let name: String
        let certificates: [ALTCertificate]
    }
    
    private func sortCertificates(_ certs: [ALTCertificate]) -> [ALTCertificate] {
        switch currentSort {
        case .creationDate:
            return certs.sorted(by: { isAscending ? $0.creationDate < $1.creationDate : $0.creationDate > $1.creationDate })
        case .expiryDate:
            return certs.sorted(by: { isAscending ? $0.expiryDate < $1.expiryDate : $0.expiryDate > $1.expiryDate })
        case .name:
            return certs.sorted(by: {
                let comparison = ($0.machineName ?? $0.name).localizedCaseInsensitiveCompare($1.machineName ?? $1.name)
                return isAscending ? comparison == .orderedAscending : comparison == .orderedDescending
            })
        case .keys:
            return certs.sorted(by: {
                let val1 = $0.privateKey != nil ? 1 : 0
                let val2 = $1.privateKey != nil ? 1 : 0
                return isAscending ? val1 < val2 : val1 > val2
            })
        }
    }
    
    private var groupedCertificatesList: [GroupedCertificates] {
        let sorted = sortCertificates(viewModel.certificates)
        switch currentGroup {
        case .none:
            return [GroupedCertificates(name: "Certificates", certificates: sorted)]
        case .keys:
            let withKeys = sorted.filter { $0.privateKey != nil }
            let withoutKeys = sorted.filter { $0.privateKey == nil }
            var groups: [GroupedCertificates] = []
            if !withKeys.isEmpty {
                groups.append(GroupedCertificates(name: "Public + Private Keys", certificates: withKeys))
            }
            if !withoutKeys.isEmpty {
                groups.append(GroupedCertificates(name: "Public Keys Only", certificates: withoutKeys))
            }
            return groups
        case .name:
            let grouped = Dictionary(grouping: sorted) { cert -> String in
                let certName = cert.machineName ?? cert.name
                guard let firstChar = certName.first else { return "#" }
                return String(firstChar).uppercased()
            }
            return grouped.keys.sorted().map { key in
                GroupedCertificates(name: key, certificates: grouped[key] ?? [])
            }
        case .creationDate:
            let grouped = Dictionary(grouping: sorted) { cert -> String in
                let year = Calendar.current.component(.year, from: cert.creationDate)
                return year > 1970 ? "Created in \(year)" : "Created (Unknown Date)"
            }
            return grouped.keys.sorted(by: >).map { key in
                GroupedCertificates(name: key, certificates: grouped[key] ?? [])
            }
        case .expiryDate:
            let grouped = Dictionary(grouping: sorted) { cert -> String in
                let year = Calendar.current.component(.year, from: cert.expiryDate)
                return year > 1970 ? "Expires in \(year)" : "Expires (Unknown Date)"
            }
            return grouped.keys.sorted(by: <).map { key in
                GroupedCertificates(name: key, certificates: grouped[key] ?? [])
            }
        }
    }
    private func displayActiveSerial(activeSerial: String) -> String {
        let isSerialRevealed = viewModel.revealedSerials.contains("active_" + activeSerial)
        let isSectionHidden = viewModel.isPrivateSectionHideActive
        let isGlobalHidden = viewModel.isGlobalHideActive
        
        if isGlobalHidden && !isSerialRevealed {
            return "••••••••••••••••"
        } else if isSectionHidden && !isSerialRevealed {
            return maskPartially(activeSerial)
        } else {
            return activeSerial
        }
    }
    
    @ViewBuilder
    private var activeLocalCertificateSection: some View {
        Section("Active Local Certificate") {
            if let activeSerial = viewModel.activeSerialNumber {
                let displaySerial = displayActiveSerial(activeSerial: activeSerial)
                
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        HStack(spacing: 6) {
                            Text("Active Signing Certificate")
                                .font(.headline)
                            
                            SwiftUI.Button {
                                UIPasteboard.general.string = activeSerial
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                hasCopiedActiveSerialNumber = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    hasCopiedActiveSerialNumber = false
                                }
                            } label: {
                                Image(systemName: hasCopiedActiveSerialNumber ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 13))
                                    .foregroundColor(hasCopiedActiveSerialNumber ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        (
                            Text("SN: ")
                                .font(.footnote)
                            +
                            Text(displaySerial)
                                .font(.system(size: 13, design: .monospaced))
                        )
                        .foregroundColor(.secondary)
                            .onTapGesture {
                                if viewModel.revealedSerials.contains("active_" + activeSerial) {
                                    viewModel.revealedSerials.remove("active_" + activeSerial)
                                } else {
                                    viewModel.revealedSerials.insert("active_" + activeSerial)
                                }
                            }
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .contextMenu {
                    SwiftUI.Button {
                        if viewModel.revealedSerials.contains("active_" + activeSerial) {
                            viewModel.revealedSerials.remove("active_" + activeSerial)
                        } else {
                            viewModel.revealedSerials.insert("active_" + activeSerial)
                        }
                    } label: {
                        Label(viewModel.revealedSerials.contains("active_" + activeSerial) ? "Hide Details" : "Reveal Details", systemImage: viewModel.revealedSerials.contains("active_" + activeSerial) ? "eye.slash" : "eye")
                    }
                    SwiftUI.Button {
                        UIPasteboard.general.string = activeSerial
                    } label: {
                        Label("Copy S/N", systemImage: "doc.on.doc")
                    }
                }
                
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .opacity(0)
                    
                    SwiftUI.Button(role: .destructive) {
                        showDeactivateConfirmation = true
                    } label: {
                        Text("Deactivate Locally")
                            .fontWeight(.medium)
                    }
                }
            } else {
                if viewModel.team == nil {
                    Text("No active local certificate found. Import a .p12 file to sign your apps.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    Text("No active local certificate found. Create a new certificate or import a .p12 file to sign your apps.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }
        }
    }
    
    @ViewBuilder
    private var certificatesListSections: some View {
        if viewModel.certificates.isEmpty {
            Section(header: Text("Certificates")) {
                if viewModel.isLoading {
                    Text("Fetching certificates...")
                        .foregroundColor(.secondary)
                } else {
                    if viewModel.team == nil {
                        Text("No local certificates found (not signed in).")
                            .foregroundColor(.secondary)
                    } else {
                        Text("No certificates found.")
                            .foregroundColor(.secondary)
                    }
                }
            }
        } else {
            ForEach(groupedCertificatesList) { group in
                Section {
                    ForEach(group.certificates, id: \.serialNumber) { cert in
                        certificateRow(cert: cert, hasPrivateKey: cert.privateKey != nil)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                pushDetailView(for: cert)
                            }
                    }
                } header: {
                    HStack(spacing: 12) {
                        Text(group.name)
                        Spacer()
                        
                        Menu {
                            ForEach(SortOption.allCases) { option in
                                SwiftUI.Button {
                                    if currentSort == option {
                                        isAscending.toggle()
                                    } else {
                                        currentSort = option
                                        isAscending = (option == .name)
                                    }
                                } label: {
                                    if currentSort == option {
                                        Label("\(option.rawValue) \(isAscending ? "↑" : "↓")", systemImage: "checkmark")
                                    } else {
                                        Text(option.rawValue)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 13))
                                .foregroundColor(.accentColor)
                        }
                        
                        Menu {
                            Picker("Group By", selection: $currentGroup) {
                                ForEach(GroupOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "rectangle.3.group")
                                .font(.system(size: 13))
                                .foregroundColor(.accentColor)
                        }
                        
                        SwiftUI.Button {
                            viewModel.isPrivateSectionHideActive.toggle()
                        } label: {
                            Image(systemName: viewModel.isPrivateSectionHideActive ? "eye.slash" : "eye")
                                .font(.subheadline)
                                .foregroundColor(viewModel.isGlobalHideActive ? .gray : .accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isGlobalHideActive)
                    }
                } footer: {
                    if group.id == groupedCertificatesList.last?.id {
                        Text("Suffix (R) indicates the certificate is registered remotely on Apple's developer portal.")
                    }
                }
            }
        }
    }

    var body: some View {
        ZStack {
            List {
                activeLocalCertificateSection
                certificatesListSections
            }
            .refreshable {
                await withCheckedContinuation { continuation in
                    viewModel.loadCertificates(presentingViewController: presentingViewController, isPullToRefresh: true) {
                        continuation.resume()
                    }
                }
            }
            .navigationTitle("Certificates")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    SwiftUI.Button {
                        viewModel.isGlobalHideActive.toggle()
                    } label: {
                        Image(systemName: viewModel.isGlobalHideActive ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel("Toggle Hide Sensitive Information")
                    
                    SwiftUI.Button {
                        self.newMachineName = "SideStore - \(UIDevice.current.name)"
                        self.showCreateDialog = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create Certificate")
                    .disabled(viewModel.team == nil)
                    
                    SwiftUI.Button {
                        self.showFileImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Import Certificates")
                }
            }
            .onAppear {
                if !hasInitialLoaded {
                    hasInitialLoaded = true
                    viewModel.loadCertificates(presentingViewController: nil)
                }
            }
            
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                        .padding(20)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            SwiftUI.Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .alert("New Certificate", isPresented: $showCreateDialog) {
            TextField("Machine Name", text: $newMachineName)
            SwiftUI.Button("Create") {
                viewModel.createCertificate(machineName: newMachineName, presentingViewController: presentingViewController)
            }
            SwiftUI.Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new certificate. This will create a new certificate on Apple's servers and store the private key locally.")
        }
        .alert("Revoke Certificate", isPresented: $showRevokeConfirmation) {
            SwiftUI.Button("Revoke", role: .destructive) {
                if let cert = certificateToRevoke {
                    viewModel.revokeCertificate(cert)
                }
            }
            SwiftUI.Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to revoke this certificate? This will permanently delete the certificate on Apple's servers and delete it locally.")
        }
        .alert("Deactivate Certificate", isPresented: $showDeactivateConfirmation) {
            SwiftUI.Button("Deactivate", role: .destructive) {
                viewModel.deactivateActiveCertificate()
            }
            SwiftUI.Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to deactivate the active signing certificate locally?")
        }
        .alert("Delete Certificate", isPresented: $showDeleteConfirmation) {
            SwiftUI.Button("Delete", role: .destructive) {
                if let cert = certificateToDelete {
                    viewModel.deleteCertificate(cert)
                }
            }
            SwiftUI.Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this certificate locally? This will remove it from the cached local store.")
        }
        .alert("Import Certificate Password", isPresented: $viewModel.showPasswordPromptForImport) {
            SecureField("Password", text: $viewModel.importPasswordInput)
            SwiftUI.Button("Import") {
                viewModel.submitImportPassword()
            }
            SwiftUI.Button("Cancel", role: .cancel) {
                viewModel.cancelImport()
            }
        } message: {
            Text("Enter the password to decrypt the imported .p12 certificate file.")
        }
        .alert("Success", isPresented: $viewModel.showAlert) {
            SwiftUI.Button("OK", role: .cancel) {
                viewModel.alertMessage = nil
            }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .alert("Export Certificate Password", isPresented: $showExportPasswordPrompt) {
            SecureField("Password", text: $exportPasswordInput)
            SwiftUI.Button("Export") {
                if let cert = certificateToExport {
                    exportCertificate(cert, password: exportPasswordInput)
                }
            }
            SwiftUI.Button("Cancel", role: .cancel) {}
        } message: {
            Text("Set a password to encrypt the exported .p12 certificate file.")
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: allowedImportTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.startBulkImport(urls: urls)
            case .failure(let error):
                viewModel.errorMessage = "Failed to select files: " + error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showKeyImporter,
            allowedContentTypes: allowedKeyImportTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first, let cert = certificateToAddKeyFor {
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let data = try Data(contentsOf: url)
                        viewModel.importPrivateKey(data: data, for: cert)
                    } catch {
                        viewModel.errorMessage = "Failed to read private key: " + error.localizedDescription
                    }
                }
            case .failure(let error):
                viewModel.errorMessage = "Failed to select private key: " + error.localizedDescription
            }
        }
        .sheet(item: $keyTextImportItem) { item in
            PrivateKeyTextInputView(
                text: $privateKeyTextInput,
                cert: item.cert,
                viewModel: viewModel,
                allowedKeyImportTypes: allowedKeyImportTypes,
                onCancel: {
                    keyTextImportItem = nil
                    privateKeyTextInput = ""
                }
            )
        }
        .alert("Clear Private Key", isPresented: $showClearKeyConfirmation) {
            if let cert = certificateToClearKeyFor {
                SwiftUI.Button("Clear Key", role: .destructive) {
                    viewModel.clearPrivateKey(for: cert)
                    self.certificateToClearKeyFor = nil
                }
            }
            SwiftUI.Button("Cancel", role: .cancel) {
                self.certificateToClearKeyFor = nil
            }
        } message: {
            if let cert = certificateToClearKeyFor {
                Text("This will clear the locally stored private key of this certificate.\n\nName: \(cert.name)\nS/N: \(cert.serialNumber)")
            }
        }
    }
    
    private func exportCertificate(_ cert: ALTCertificate, password: String) {
        guard let p12Data = cert.encryptedP12Data(password: password) else {
            viewModel.errorMessage = "Failed to export certificate."
            return
        }
        
        let filename = (cert.machineName ?? cert.name) + ".p12"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try p12Data.write(to: tempURL)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                let presenter = rootVC.presentedViewController ?? rootVC
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = presenter.view
                    popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                presenter.present(activityVC, animated: true, completion: nil)
            }
        } catch {
            viewModel.errorMessage = "Failed to write temp export file: " + error.localizedDescription
        }
    }
    
    private func exportPublicCertificateAsDER(_ cert: ALTCertificate) {
        guard let data = cert.data else {
            viewModel.errorMessage = "Public certificate data is missing."
            return
        }
        
        let filename = (cert.machineName ?? cert.name) + ".der"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            let derData = getDERData(from: data) ?? data
            try derData.write(to: tempURL)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                let presenter = rootVC.presentedViewController ?? rootVC
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = presenter.view
                    popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                presenter.present(activityVC, animated: true, completion: nil)
            }
        } catch {
            viewModel.errorMessage = "Failed to write temp export file: " + error.localizedDescription
        }
    }
    
    private func exportPublicCertificateAsPEM(_ cert: ALTCertificate) {
        guard let data = cert.data else {
            viewModel.errorMessage = "Public certificate data is missing."
            return
        }
        
        let filename = (cert.machineName ?? cert.name) + ".pem"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: tempURL)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                let presenter = rootVC.presentedViewController ?? rootVC
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = presenter.view
                    popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                presenter.present(activityVC, animated: true, completion: nil)
            }
        } catch {
            viewModel.errorMessage = "Failed to write temp export file: " + error.localizedDescription
        }
    }
    
    private func copyPublicCertificateAsPEM(_ cert: ALTCertificate) {
        guard let data = cert.data else {
            viewModel.errorMessage = "Public certificate data is missing."
            return
        }
        if let pemString = String(data: data, encoding: .utf8) {
            UIPasteboard.general.string = pemString
        } else {
            UIPasteboard.general.string = data.base64EncodedString()
        }
    }
    
    private func maskPartially(_ string: String) -> String {
        guard string.count > 8 else { return "••••••••" }
        return "\(string.prefix(4))••••••••\(string.suffix(4))"
    }
    
    private func displaySerial(for cert: ALTCertificate, hasPrivateKey: Bool) -> String {
        let isRowLocallyRevealed = viewModel.revealedSerials.contains(cert.serialNumber)
        let isSectionHidden = hasPrivateKey ? viewModel.isPrivateSectionHideActive : viewModel.isPublicSectionHideActive
        let isGlobalHidden = viewModel.isGlobalHideActive
        
        if isGlobalHidden && !isRowLocallyRevealed {
            return "••••••••••••••••"
        } else if isSectionHidden && !isRowLocallyRevealed {
            return maskPartially(cert.serialNumber)
        } else {
            return cert.serialNumber
        }
    }
    
    private func displayIdentifier(for cert: ALTCertificate, hasPrivateKey: Bool) -> String? {
        guard let ident = cert.identifier else { return nil }
        let isRowLocallyRevealed = viewModel.revealedSerials.contains(cert.serialNumber)
        let isSectionHidden = hasPrivateKey ? viewModel.isPrivateSectionHideActive : viewModel.isPublicSectionHideActive
        let isGlobalHidden = viewModel.isGlobalHideActive
        
        if (isGlobalHidden || isSectionHidden) && !isRowLocallyRevealed {
            return "••••••••••"
        } else {
            return ident
        }
    }

    private func displayRequester(for cert: ALTCertificate, hasPrivateKey: Bool) -> String? {
        guard let requester = cert.requesterEmail, !requester.isEmpty else { return nil }
        let isRowLocallyRevealed = viewModel.revealedSerials.contains(cert.serialNumber)
        let isSectionHidden = hasPrivateKey ? viewModel.isPrivateSectionHideActive : viewModel.isPublicSectionHideActive
        let isGlobalHidden = viewModel.isGlobalHideActive
        
        if (isGlobalHidden || isSectionHidden) && !isRowLocallyRevealed {
            return "••••••••••"
        } else {
            return requester
        }
    }

    private func displayBriefType(for brief: CertificateBriefInfo, cert: ALTCertificate) -> String {
        let isRowLocallyRevealed = viewModel.revealedSerials.contains(cert.serialNumber)
        let isGlobalHidden = viewModel.isGlobalHideActive
        
        if isGlobalHidden && !isRowLocallyRevealed {
            return "••••••••••"
        } else {
            return brief.type
        }
    }

    private func displayBriefValidity(for brief: CertificateBriefInfo, cert: ALTCertificate) -> String {
        let isRowLocallyRevealed = viewModel.revealedSerials.contains(cert.serialNumber)
        let isGlobalHidden = viewModel.isGlobalHideActive
        
        if isGlobalHidden && !isRowLocallyRevealed {
            return "••••••••••"
        } else {
            return "\(brief.validFrom) - \(brief.validUntil)"
        }
    }
    
    @ViewBuilder
    private func certificateRow(cert: ALTCertificate, hasPrivateKey: Bool) -> some View {
        let isActive = cert.serialNumber == viewModel.activeSerialNumber
        let isRemote = viewModel.remoteSerials.contains(cert.serialNumber)
        
        let isSectionHidden = hasPrivateKey ? viewModel.isPrivateSectionHideActive : viewModel.isPublicSectionHideActive
        let isGlobalHidden = viewModel.isGlobalHideActive
        
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text((cert.machineName ?? cert.name) + (isRemote ? " (R)" : ""))
                    .font(.headline)
                (
                    Text("Serial: ")
                        .font(.system(size: 11))
                    +
                    Text(displaySerial(for: cert, hasPrivateKey: hasPrivateKey))
                        .font(.system(size: 11, design: .monospaced))
                )
                .foregroundColor(.secondary)
                .onTapGesture {
                    if viewModel.revealedSerials.contains(cert.serialNumber) {
                        viewModel.revealedSerials.remove(cert.serialNumber)
                    } else {
                        viewModel.revealedSerials.insert(cert.serialNumber)
                    }
                }
                if let displayIdent = displayIdentifier(for: cert, hasPrivateKey: hasPrivateKey) {
                    (
                        Text("ID: ")
                            .font(.system(size: 10))
                        +
                        Text(displayIdent)
                            .font(.system(size: 10, design: .monospaced))
                    )
                    .foregroundColor(.gray)
                }
                if let brief = getBriefInfo(for: cert.data) {
                    let displayType = displayBriefType(for: brief, cert: cert)
                    let isTypeHidden = displayType.contains("•")
                    (
                        Text("Type: ")
                            .font(.system(size: 10))
                        +
                        Text(displayType)
                            .font(isTypeHidden ? .system(size: 10, design: .monospaced) : .system(size: 10))
                    )
                    .foregroundColor(.secondary)
                    
                    let displayValidity = displayBriefValidity(for: brief, cert: cert)
                    let isValidityHidden = displayValidity.contains("•")
                    (
                        Text("Validity: ")
                            .font(.system(size: 10))
                        +
                        Text(displayValidity)
                            .font(isValidityHidden ? .system(size: 10, design: .monospaced) : .system(size: 10))
                    )
                    .foregroundColor(.secondary)
                }
                if let displayReq = displayRequester(for: cert, hasPrivateKey: hasPrivateKey) {
                    let isReqHidden = displayReq.contains("•")
                    (
                        Text("Requester: ")
                            .font(.system(size: 10))
                        +
                        Text(displayReq)
                            .font(isReqHidden ? .system(size: 10, design: .monospaced) : .system(size: 10))
                    )
                    .foregroundColor(.secondary)
                }
                (
                    Text("Keys: ")
                        .font(.system(size: 10))
                    +
                    Text(hasPrivateKey ? "public + private" : "public")
                        .font(.system(size: 10))
                )
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                } else if isRemote {
                    SwiftUI.Button {
                        self.certificateToRevoke = cert
                        self.showRevokeConfirmation = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                
                 Image(systemName: "chevron.right")
                     .foregroundColor(Color(.tertiaryLabel))
                     .font(.footnote)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            SwiftUI.Button {
                if viewModel.revealedSerials.contains(cert.serialNumber) {
                    viewModel.revealedSerials.remove(cert.serialNumber)
                } else {
                    viewModel.revealedSerials.insert(cert.serialNumber)
                }
            } label: {
                Label(viewModel.revealedSerials.contains(cert.serialNumber) ? "Hide Details" : "Reveal Details", systemImage: viewModel.revealedSerials.contains(cert.serialNumber) ? "eye.slash" : "eye")
            }
            if hasPrivateKey && !isActive {
                SwiftUI.Button {
                    viewModel.makeCertificateActive(cert)
                } label: {
                    Label("Activate", systemImage: "key.fill")
                }
            }
            
            SwiftUI.Button {
                UIPasteboard.general.string = cert.serialNumber
            } label: {
                Label("Copy S/N", systemImage: "doc.on.doc")
            }
            
            if hasPrivateKey {
                SwiftUI.Button {
                    self.certificateToExport = cert
                    self.exportPasswordInput = ""
                    self.showExportPasswordPrompt = true
                } label: {
                    Label("Export (.p12)", systemImage: "square.and.arrow.up")
                }
                
                SwiftUI.Button {
                    if let keyData = cert.privateKey, let pemString = String(data: keyData, encoding: .utf8) {
                        UIPasteboard.general.string = pemString
                    } else if let keyData = cert.privateKey {
                        UIPasteboard.general.string = keyData.base64EncodedString()
                    }
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                } label: {
                    Label("Copy Private Key", systemImage: "doc.on.doc")
                }
                
                SwiftUI.Button(role: .destructive) {
                    self.certificateToClearKeyFor = cert
                    self.showClearKeyConfirmation = true
                } label: {
                    Label("Clear pKey", systemImage: "key.slash")
                }
            } else {
                SwiftUI.Button {
                    self.keyTextImportItem = KeyTextImportItem(id: cert.serialNumber, cert: cert)
                } label: {
                    Label("Add pKey (text)", systemImage: "square.and.pencil")
                }
                
                SwiftUI.Button {
                    self.certificateToAddKeyFor = cert
                    self.showKeyImporter = true
                } label: {
                    Label("Add pKey (bin)", systemImage: "doc.badge.plus")
                }
                
                SwiftUI.Button {
                    exportPublicCertificateAsDER(cert)
                } label: {
                    Label("Export (.der)", systemImage: "square.and.arrow.up")
                }
                
                SwiftUI.Button {
                    exportPublicCertificateAsPEM(cert)
                } label: {
                    Label("Export (.pem)", systemImage: "square.and.arrow.up")
                }
                
                SwiftUI.Button {
                    copyPublicCertificateAsPEM(cert)
                } label: {
                    Label("Copy (.pem)", systemImage: "doc.on.doc")
                }
            }
            
            if viewModel.isCertificateLocallyCached(cert) {
                SwiftUI.Button(role: .destructive) {
                    self.certificateToDelete = cert
                    self.showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    private func pushDetailView(for cert: ALTCertificate) {
        let metadata = DeveloperPortalMetadata(
            identifier: cert.identifier,
            machineName: cert.machineName,
            machineIdentifier: cert.machineIdentifier,
            requesterEmail: cert.requesterEmail
        )
        let detailView = CertificateDetailView(certificate: cert, portalMetadata: metadata)
        let detailVC = UIHostingController(rootView: detailView)
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        detailVC.navigationItem.scrollEdgeAppearance = appearance
        detailVC.navigationItem.standardAppearance = appearance
        
        presentingViewController?.navigationController?.pushViewController(detailVC, animated: true)
    }
}

extension ALTCertificate: Identifiable {
    public var id: String {
        return self.serialNumber
    }
}

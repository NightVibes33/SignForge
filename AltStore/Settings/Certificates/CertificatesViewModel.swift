//
//  CertificatesViewModel.swift
//  AltStore
//
//  Created by Magesh K on 2026-06-29.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import AltSign
import KeychainAccess
import AltStoreCore

struct PendingImport {
    let url: URL
    let filename: String
}

class CertificatesViewModel: ObservableObject {
    @Published var certificates: [ALTCertificate] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil {
        didSet {
            showErrorAlert = errorMessage != nil
        }
    }
    @Published var showErrorAlert = false
    @Published var activeSerialNumber: String? = nil
    @Published var alertMessage: String? = nil
    @Published var showAlert = false
    @Published var remoteSerials: Set<String> = []
    
    // Privacy and masking properties
    @Published var isGlobalHideActive = false {
        didSet {
            revealedSerials.removeAll()
        }
    }
    #if DEBUG
    @Published var isPrivateSectionHideActive = false {
        didSet {
            revealedSerials.removeAll()
        }
    }
    @Published var isPublicSectionHideActive = false {
        didSet {
            revealedSerials.removeAll()
        }
    }
    #else
    @Published var isPrivateSectionHideActive = true {
        didSet {
            revealedSerials.removeAll()
        }
    }
    @Published var isPublicSectionHideActive = true {
        didSet {
            revealedSerials.removeAll()
        }
    }
    #endif
    @Published var revealedSerials: Set<String> = []
    
    // Bulk import properties
    @Published var pendingImports: [PendingImport] = []
    @Published var currentImportIndex = 0
    @Published var showPasswordPromptForImport = false
    @Published var importPasswordInput = ""
    
    var lastUsedPassword = ""
    var session: ALTAppleAPISession?
    var team: ALTTeam?
    
    var isPaidAccount: Bool {
        guard let team = self.team else { return false }
        return team.type != .free && team.type != .unknown
    }
    
    func fetchActiveSerialNumber() {
        if let data = Keychain.shared.signingCertificate {
            let cert = (try? ALTCertificate(p12Data: data, password: "")) ?? (try? ALTCertificate(p12Data: data, password: nil))
            if let cert = cert {
                self.activeSerialNumber = cert.serialNumber
                return
            }
        }
        self.activeSerialNumber = nil
    }
    
    // MARK: - Local Storage Helpers
    
    private let certificateKeychain = KeychainAccess.Keychain(service: Bundle.Info.appbundleIdentifier).accessibility(.afterFirstUnlock)
    
    func loadLocalCertificates() -> [ALTCertificate] {
        var localCerts: [ALTCertificate] = []
        let serials = UserDefaults.standard.stringArray(forKey: "importedCertificateSerials") ?? []
        for serial in serials {
            if let data = try? self.certificateKeychain.getData("importedCert_" + serial) {
                var loadedCert: ALTCertificate? = nil
                if let cert = (try? ALTCertificate(p12Data: data, password: "")) ?? (try? ALTCertificate(p12Data: data, password: nil)) {
                    loadedCert = cert
                } else if let cert = ALTCertificate(data: data) {
                    loadedCert = cert
                }
                
                if let cert = loadedCert {
                    if let metadata = UserDefaults.standard.dictionary(forKey: "certMetadata_" + cert.serialNumber) as? [String: String] {
                        cert.machineName = metadata["machineName"]
                        cert.identifier = metadata["identifier"]
                        cert.requesterEmail = metadata["requesterEmail"]
                        cert.machineIdentifier = metadata["machineIdentifier"]
                    }
                    localCerts.append(cert)
                }
            }
        }
        return localCerts
    }
    
    func saveLocalCertificate(_ cert: ALTCertificate) {
        if let p12Data = cert.p12Data() {
            try? self.certificateKeychain.set(p12Data, key: "importedCert_" + cert.serialNumber)
        } else if let derData = cert.data {
            try? self.certificateKeychain.set(derData, key: "importedCert_" + cert.serialNumber)
        } else {
            return
        }
        
        var serials = UserDefaults.standard.stringArray(forKey: "importedCertificateSerials") ?? []
        if !serials.contains(cert.serialNumber) {
            serials.append(cert.serialNumber)
            UserDefaults.standard.set(serials, forKey: "importedCertificateSerials")
        }
        
        var metadataDict: [String: String] = [:]
        if let machineName = cert.machineName {
            metadataDict["machineName"] = machineName
        }
        if let identifier = cert.identifier {
            metadataDict["identifier"] = identifier
        }
        if let requesterEmail = cert.requesterEmail {
            metadataDict["requesterEmail"] = requesterEmail
        }
        if let machineIdentifier = cert.machineIdentifier {
            metadataDict["machineIdentifier"] = machineIdentifier
        }
        UserDefaults.standard.set(metadataDict, forKey: "certMetadata_" + cert.serialNumber)
    }
    
    func deleteLocalCertificate(serialNumber: String) {
        try? self.certificateKeychain.remove("importedCert_" + serialNumber)
        
        var serials = UserDefaults.standard.stringArray(forKey: "importedCertificateSerials") ?? []
        serials.removeAll(where: { $0 == serialNumber })
        UserDefaults.standard.set(serials, forKey: "importedCertificateSerials")
    }
    
    private var activeLocalCert: ALTCertificate? {
        guard let data = Keychain.shared.signingCertificate else { return nil }
        let cert = (try? ALTCertificate(p12Data: data, password: "")) ?? (try? ALTCertificate(p12Data: data, password: nil))
        if let cert = cert {
            if let metadata = UserDefaults.standard.dictionary(forKey: "certMetadata_" + cert.serialNumber) as? [String: String] {
                cert.machineName = metadata["machineName"]
                cert.identifier = metadata["identifier"]
                cert.requesterEmail = metadata["requesterEmail"]
                cert.machineIdentifier = metadata["machineIdentifier"]
            }
            return cert
        }
        return nil
    }
    
    // MARK: - Fetch & Load
    
    func loadCertificates(presentingViewController: UIViewController?, isPullToRefresh: Bool = false, completion: (() -> Void)? = nil) {
        if !isPullToRefresh {
            self.isLoading = true
        }
        self.errorMessage = nil
        self.fetchActiveSerialNumber()
        
        let localCerts = self.loadLocalCertificates()
        let activeCert = self.activeLocalCert
        
        // Show local certificates immediately
        var mergedLocal = localCerts
        if let active = activeCert, !mergedLocal.contains(where: { $0.serialNumber == active.serialNumber }) {
            mergedLocal.append(active)
        }
        self.certificates = mergedLocal
        
        Task { @MainActor in
            defer {
                self.isLoading = false
                completion?()
            }
            
            let hasPassword = Keychain.shared.appleIDPassword != nil
            let hasToken = Keychain.shared.appleIDXcodeToken != nil
            guard Keychain.shared.appleIDEmailAddress != nil && (hasPassword || hasToken) else {
                if isPullToRefresh {
                    self.errorMessage = OperationError.notAuthenticated.localizedDescription
                }
                return
            }
            
            do {
                let (team, session) = try await DeveloperPortalService.shared.authenticate(presentingViewController: presentingViewController)
                self.team = team
                self.session = session
                
                let remoteCerts = try await DeveloperPortalService.shared.fetchCertificates(team: team, session: session)
                
                var merged: [ALTCertificate] = []
                var matchedRemoteSerials = Set<String>()
                
                for remoteCert in remoteCerts {
                    var resolvedPrivateKey: Data? = nil
                    
                    if let active = activeCert, active.serialNumber == remoteCert.serialNumber, active.privateKey != nil {
                        resolvedPrivateKey = active.privateKey
                    } else if let localCopy = localCerts.first(where: { $0.serialNumber == remoteCert.serialNumber && $0.privateKey != nil }) {
                        resolvedPrivateKey = localCopy.privateKey
                    }
                    
                    remoteCert.privateKey = resolvedPrivateKey
                    
                    // Automatically cache/save the fetched remote certificate locally!
                    self.saveLocalCertificate(remoteCert)
                    
                    merged.append(remoteCert)
                    matchedRemoteSerials.insert(remoteCert.serialNumber)
                }
                
                for localCert in localCerts {
                    if !matchedRemoteSerials.contains(localCert.serialNumber) {
                        merged.append(localCert)
                    }
                }
                
                if let active = activeCert, !matchedRemoteSerials.contains(active.serialNumber) {
                    if !localCerts.contains(where: { $0.serialNumber == active.serialNumber }) {
                        merged.append(active)
                    }
                }
                
                self.certificates = merged
                self.remoteSerials = matchedRemoteSerials
            } catch {
                let isCancelled = error is CancellationError
                if !isCancelled {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Bulk Import Password Caching Flow
    
    func startBulkImport(urls: [URL]) {
        self.pendingImports = urls.map { PendingImport(url: $0, filename: $0.lastPathComponent) }
        self.currentImportIndex = 0
        processNextImport()
    }
    
    func processNextImport() {
        guard currentImportIndex < pendingImports.count else {
            self.pendingImports = []
            self.loadCertificates(presentingViewController: nil)
            return
        }
        
        let pending = pendingImports[currentImportIndex]
        let url = pending.url
        
        if !lastUsedPassword.isEmpty && tryUnlock(url: url, password: lastUsedPassword) {
            currentImportIndex += 1
            processNextImport()
            return
        }
        
        if tryUnlock(url: url, password: "") {
            currentImportIndex += 1
            processNextImport()
            return
        }
        
        DispatchQueue.main.async {
            self.importPasswordInput = ""
            self.showPasswordPromptForImport = true
        }
    }
    
    func submitImportPassword() {
        let pending = pendingImports[currentImportIndex]
        let url = pending.url
        let password = importPasswordInput
        
        if tryUnlock(url: url, password: password) {
            self.lastUsedPassword = password
            self.showPasswordPromptForImport = false
            self.currentImportIndex += 1
            self.processNextImport()
        } else {
            self.errorMessage = "Incorrect password for " + pending.filename
        }
    }
    
    func cancelImport() {
        self.pendingImports = []
        self.showPasswordPromptForImport = false
    }
    
    private func tryUnlock(url: URL, password: String) -> Bool {
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let certData = try? Data(contentsOf: url) else { return false }
        
        // 1. Try public-only certificate format (DER/PEM) first. If valid, import immediately without password prompt.
        if let rawCert = ALTCertificate(data: certData) {
            saveLocalCertificate(rawCert)
            return true
        }
        
        // 2. Otherwise, treat as PKCS#12 format and try to unlock.
        if let altCert = try? ALTCertificate(p12Data: certData, password: password) {
            saveLocalCertificate(altCert)
            return true
        }
        
        return false
    }
    
    // MARK: - Certificate Management Actions
    
    func createCertificate(machineName: String, presentingViewController: UIViewController?) {
        guard let team = self.team, let session = self.session else {
            self.errorMessage = "Not authenticated"
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        Task { @MainActor in
            defer {
                self.isLoading = false
            }
            
            do {
                let newCert = try await DeveloperPortalService.shared.createCertificate(machineName: machineName, team: team, session: session)
                guard let privateKey = newCert.privateKey else {
                    self.errorMessage = "Missing private key from newly created certificate."
                    return
                }
                
                let remoteCerts = try await DeveloperPortalService.shared.fetchCertificates(team: team, session: session)
                if let certificate = remoteCerts.first(where: { $0.serialNumber == newCert.serialNumber }) {
                    certificate.privateKey = privateKey
                    self.saveLocalCertificate(certificate)
                    
                    self.alertMessage = "Certificate created successfully."
                    self.showAlert = true
                    
                    self.loadCertificates(presentingViewController: nil)
                }
            } catch {
                let errorString = error.localizedDescription
                let isCancelled = error is CancellationError
                if !isCancelled {
                    self.errorMessage = errorString
                }
            }
        }
    }
    
    func revokeCertificate(_ certificate: ALTCertificate) {
        guard let team = self.team, let session = self.session else {
            self.errorMessage = "Not authenticated"
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        Task { @MainActor in
            defer {
                self.isLoading = false
            }
            
            do {
                let success = try await DeveloperPortalService.shared.revokeCertificate(certificate, team: team, session: session)
                if success {
                    self.deleteLocalCertificate(serialNumber: certificate.serialNumber)
                    self.certificates.removeAll(where: { $0.serialNumber == certificate.serialNumber })
                    
                    if self.activeSerialNumber == certificate.serialNumber {
                        Keychain.shared.signingCertificate = nil
                        Keychain.shared.signingCertificatePassword = nil
                        self.activeSerialNumber = nil
                    }
                    self.alertMessage = "Certificate revoked successfully."
                    self.showAlert = true
                } else {
                    self.errorMessage = "Failed to revoke certificate."
                }
            } catch {
                let errorString = error.localizedDescription
                let isCancelled = error is CancellationError
                if !isCancelled {
                    self.errorMessage = errorString
                }
            }
        }
    }
    
    func deleteCertificate(_ certificate: ALTCertificate) {
        deleteLocalCertificate(serialNumber: certificate.serialNumber)
        self.certificates.removeAll(where: { $0.serialNumber == certificate.serialNumber })
        
        if self.activeSerialNumber == certificate.serialNumber {
            Keychain.shared.signingCertificate = nil
            Keychain.shared.signingCertificatePassword = nil
            self.activeSerialNumber = nil
        }
        self.alertMessage = "Certificate deleted locally."
        self.showAlert = true
    }
    
    func makeCertificateActive(_ certificate: ALTCertificate) {
        guard certificate.privateKey != nil else {
            self.errorMessage = "Cannot activate certificate: private key missing."
            return
        }
        
        Keychain.shared.signingCertificate = certificate.p12Data()
        Keychain.shared.signingCertificatePassword = certificate.machineIdentifier ?? ""
        self.fetchActiveSerialNumber()
        
        self.alertMessage = "Active signing certificate replaced successfully."
        self.showAlert = true
    }
    
    func deactivateActiveCertificate() {
        Keychain.shared.signingCertificate = nil
        Keychain.shared.signingCertificatePassword = nil
        self.activeSerialNumber = nil
        self.alertMessage = "Local certificate deactivated."
        self.showAlert = true
    }
    
    func isCertificateLocallyCached(_ certificate: ALTCertificate) -> Bool {
        let serials = UserDefaults.standard.stringArray(forKey: "importedCertificateSerials") ?? []
        return serials.contains(certificate.serialNumber) || certificate.serialNumber == self.activeSerialNumber
    }
}

enum PrivateKeyImportError: LocalizedError {
    case isCertificate
    case invalidKey
    case conversionFailed
    
    var errorDescription: String? {
        switch self {
        case .isCertificate:
            return "The selected file is a certificate, not a private key."
        case .invalidKey:
            return "The input does not contain a valid private key."
        case .conversionFailed:
            return "Failed to convert binary private key to PEM format."
        }
    }
}

extension CertificatesViewModel {
    private func derToPEM(derData: Data) -> Data? {
        let base64 = derData.base64EncodedString(options: [.lineLength64Characters])
        let pemString = "-----BEGIN PRIVATE KEY-----\n\(base64)\n-----END PRIVATE KEY-----"
        return pemString.data(using: .utf8)
    }
    
    func validateAndFormatPrivateKey(data: Data) throws -> Data {
        // 1. Check if the input data is a certificate
        if let _ = SecCertificateCreateWithData(nil, data as CFData) {
            throw PrivateKeyImportError.isCertificate
        }
        
        // 2. Try to validate as an RSA/EC private key using SecKeyCreateWithData
        let rsaAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]
        var error: Unmanaged<CFError>?
        if let _ = SecKeyCreateWithData(data as CFData, rsaAttributes as CFDictionary, &error) {
            guard let pemData = derToPEM(derData: data) else {
                throw PrivateKeyImportError.conversionFailed
            }
            return pemData
        }
        
        let ecAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeEC,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]
        if let _ = SecKeyCreateWithData(data as CFData, ecAttributes as CFDictionary, nil) {
            guard let pemData = derToPEM(derData: data) else {
                throw PrivateKeyImportError.conversionFailed
            }
            return pemData
        }
        
        // 3. Check if it's already a valid PEM string
        if let pemString = String(data: data, encoding: .utf8) {
            let clean = pemString.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasBegin = clean.contains("-----BEGIN PRIVATE KEY-----")        ||
                           clean.contains("-----BEGIN RSA PRIVATE KEY-----")    ||
                           clean.contains("-----BEGIN EC PRIVATE KEY-----")     ||
                           clean.contains("-----BEGIN DSA PRIVATE KEY-----")
            
            let hasEnd = clean.contains("-----END PRIVATE KEY-----")            ||
                         clean.contains("-----END RSA PRIVATE KEY-----")        ||
                         clean.contains("-----END EC PRIVATE KEY-----")         ||
                         clean.contains("-----END DSA PRIVATE KEY-----")
            
            if hasBegin && hasEnd {
                return data
            }
        }
        
        throw PrivateKeyImportError.invalidKey
    }
    
    func importPrivateKey(data: Data, for cert: ALTCertificate) {
        do {
            let formattedKey = try validateAndFormatPrivateKey(data: data)
            cert.privateKey = formattedKey
            saveLocalCertificate(cert)
            self.loadCertificates(presentingViewController: nil)
            
            self.alertMessage = "Successfully added private key to certificate \(cert.name)."
            self.showAlert = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func clearPrivateKey(for cert: ALTCertificate) {
        cert.privateKey = nil
        saveLocalCertificate(cert)
        self.loadCertificates(presentingViewController: nil)
        
        self.alertMessage = "Successfully removed private key from certificate \(cert.name)."
        self.showAlert = true
    }
}

import Foundation
import CryptoKit
import Security

enum SigningCryptoError: Error, LocalizedError {
    case keyGenerationFailed(OSStatus)
    case keyLookupFailed(OSStatus)
    case publicKeyUnavailable
    case publicKeyExportFailed
    case signingFailed
    case nonExportableKey
    case unsupportedExport

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed(let status): return "Key generation failed with status \(status)."
        case .keyLookupFailed(let status): return "Key lookup failed with status \(status)."
        case .publicKeyUnavailable: return "Could not read the generated public key."
        case .publicKeyExportFailed: return "Could not export the public key for fingerprinting."
        case .signingFailed: return "Could not sign the CSR."
        case .nonExportableKey: return "Secure Enclave keys cannot be exported into a P12."
        case .unsupportedExport: return "PKCS#12 export needs the production PKCS#12 backend before export."
        }
    }
}

struct SigningCrypto {
    func generateSoftwareKey(label: String) throws -> SigningKey {
        let tag = "com.nightvibes.signforge.keys." + UUID().uuidString
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: Data(tag.utf8),
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            let status = (error?.takeRetainedValue() as NSError?)?.code ?? Int(errSecParam)
            throw SigningCryptoError.keyGenerationFailed(OSStatus(status))
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else { throw SigningCryptoError.publicKeyUnavailable }
        let publicData = try exportPublicKey(publicKey)
        let fingerprint = SHA256.hash(data: publicData).map { String(format: "%02X", $0) }.joined(separator: ":")
        return SigningKey(label: label, algorithm: "RSA 2048", fingerprint: fingerprint, keychainTag: tag, exportable: true)
    }

    func generateCSR(commonName: String, organization: String, country: String, key: SigningKey) throws -> String {
        guard let tag = key.keychainTag else { throw SigningCryptoError.keyLookupFailed(errSecItemNotFound) }
        let privateKey = try loadPrivateKey(tag: tag)
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else { throw SigningCryptoError.publicKeyUnavailable }
        let publicData = try exportPublicKey(publicKey)
        let cri = DER.sequence([DER.integer(0), subject(commonName: commonName, organization: organization, country: country), subjectPublicKeyInfo(publicData), DER.context0(Data())])
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey, .rsaSignatureMessagePKCS1v15SHA256, cri as CFData, &error) as Data? else { throw SigningCryptoError.signingFailed }
        let csr = DER.sequence([cri, sha256RSAAlgorithm(), DER.bitString(signature)])
        return pem(label: "CERTIFICATE REQUEST", der: csr)
    }

    func exportPrivateKeyPEM(key: SigningKey) throws -> String {
        guard key.exportable else { throw SigningCryptoError.nonExportableKey }
        guard let tag = key.keychainTag else { throw SigningCryptoError.keyLookupFailed(errSecItemNotFound) }
        let privateKey = try loadPrivateKey(tag: tag)
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(privateKey, &error) as Data? else { throw SigningCryptoError.publicKeyExportFailed }
        return pem(label: "RSA PRIVATE KEY", der: data)
    }

    func exportP12(certificate: CertificateRecord, key: SigningKey, password: String) throws -> Data {
        guard key.exportable else { throw SigningCryptoError.nonExportableKey }
        throw SigningCryptoError.unsupportedExport
    }

    private func loadPrivateKey(tag: String) throws -> SecKey {
        let query: [String: Any] = [kSecClass as String: kSecClassKey, kSecAttrApplicationTag as String: Data(tag.utf8), kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecReturnRef as String: true]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let key = result else { throw SigningCryptoError.keyLookupFailed(status) }
        return key as! SecKey
    }

    private func exportPublicKey(_ key: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(key, &error) as Data? else { throw SigningCryptoError.publicKeyExportFailed }
        return data
    }

    private func subject(commonName: String, organization: String, country: String) -> Data {
        DER.sequence([rdn(oid: [0x55, 0x04, 0x06], value: country), rdn(oid: [0x55, 0x04, 0x0A], value: organization), rdn(oid: [0x55, 0x04, 0x03], value: commonName)])
    }

    private func rdn(oid: [UInt8], value: String) -> Data {
        DER.set([DER.sequence([DER.objectIdentifier(oid), DER.utf8String(value)])])
    }

    private func subjectPublicKeyInfo(_ publicKey: Data) -> Data {
        DER.sequence([rsaAlgorithm(), DER.bitString(publicKey)])
    }

    private func rsaAlgorithm() -> Data { DER.sequence([DER.objectIdentifier([0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]), DER.null()]) }
    private func sha256RSAAlgorithm() -> Data { DER.sequence([DER.objectIdentifier([0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B]), DER.null()]) }

    private func pem(label: String, der: Data) -> String {
        let body = der.base64EncodedString(options: [.lineLength64Characters])
        return "-----BEGIN \(label)-----\n\(body)\n-----END \(label)-----"
    }
}

import Foundation
import CryptoKit

enum SigningCryptoError: Error, LocalizedError {
    case nonExportableKey
    case unsupportedExport

    var errorDescription: String? {
        switch self {
        case .nonExportableKey: return "Secure Enclave keys cannot be exported into a P12."
        case .unsupportedExport: return "Native PKCS#12 export is not implemented in this scaffold."
        }
    }
}

struct SigningCrypto {
    func generateSoftwareKey(label: String) -> SigningKey {
        let seed = SymmetricKey(size: .bits256)
        let data = seed.withUnsafeBytes { Data($0) }
        let fingerprint = SHA256.hash(data: data).prefix(8).map { String(format: "%02X", $0) }.joined(separator: ":")
        return SigningKey(label: label, algorithm: "RSA 2048 placeholder", fingerprint: fingerprint, exportable: true)
    }

    func generateCSR(commonName: String, organization: String, country: String, key: SigningKey) -> String {
        """
        -----BEGIN CERTIFICATE REQUEST-----
        SIGNFORGE-CSR
        CN=\(commonName)
        O=\(organization)
        C=\(country)
        KEY=\(key.fingerprint)
        -----END CERTIFICATE REQUEST-----
        """
    }

    func exportP12(certificate: CertificateRecord, key: SigningKey, password: String) throws -> Data {
        guard key.exportable else { throw SigningCryptoError.nonExportableKey }
        throw SigningCryptoError.unsupportedExport
    }
}

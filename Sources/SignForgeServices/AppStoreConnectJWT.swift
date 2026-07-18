import CryptoKit
import Foundation

enum AppStoreConnectJWTError: Error, LocalizedError {
    case invalidPrivateKey
    case signingFailed

    var errorDescription: String? {
        switch self {
        case .invalidPrivateKey: return "The .p8 key could not be parsed as an App Store Connect API private key."
        case .signingFailed: return "Could not sign the App Store Connect JWT."
        }
    }
}

struct AppStoreConnectJWT {
    func makeToken(issuerID: String, keyID: String, privateKeyPEM: String, issuedAt: Date = Date()) throws -> String {
        let header = ["alg": "ES256", "kid": keyID, "typ": "JWT"]
        let payload: [String: Any] = ["iss": issuerID, "iat": Int(issuedAt.timeIntervalSince1970), "exp": Int(issuedAt.addingTimeInterval(20 * 60).timeIntervalSince1970), "aud": "appstoreconnect-v1"]
        let headerData = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let signingInput = headerData.base64URLString + "." + payloadData.base64URLString
        let key = try P256.Signing.PrivateKey(pemRepresentation: privateKeyPEM)
        let signature = try key.signature(for: Data(signingInput.utf8)).rawRepresentation.base64URLString
        return signingInput + "." + signature
    }
}

extension Data {
    var base64URLString: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

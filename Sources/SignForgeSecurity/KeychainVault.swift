import Foundation
import Security

enum KeychainVaultError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case dataEncodingFailed

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status): return "Keychain operation failed with status \(status)."
        case .dataEncodingFailed: return "Could not encode keychain data."
        }
    }
}

struct KeychainVault {
    var service = "com.nightvibes.signforge.vault"

    func saveString(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainVaultError.dataEncodingFailed }
        try saveData(data, account: account)
    }

    func loadString(account: String) throws -> String? {
        guard let data = try loadData(account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveData(_ data: Data, account: String) throws {
        let query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainVaultError.unexpectedStatus(status) }
    }

    func loadData(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainVaultError.unexpectedStatus(status) }
        return result as? Data
    }

    func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainVaultError.unexpectedStatus(status) }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
}

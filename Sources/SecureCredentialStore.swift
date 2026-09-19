import Foundation
import Security

/// Stores API credentials in the user's macOS Keychain.
///
/// Legacy plaintext key files are migrated lazily: the value is first written to Keychain,
/// verified by reading it back, and only then are the plaintext files deleted. If Keychain
/// access fails, the legacy file is left untouched so an existing user never loses a key.
final class SecureCredentialStore {
    static let shared = SecureCredentialStore()

    private let service: String

    init(service: String = "com.game.whisperapp.credentials") {
        self.service = service
    }

    func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @discardableResult
    func write(_ value: String, account: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return delete(account: account)
        }
        guard let data = trimmed.data(using: .utf8) else { return false }

        let key: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let updateStatus = SecItemUpdate(key as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var add = key
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Returns a Keychain value, or migrates the first non-empty legacy plaintext file.
    func migrateLegacyKey(account: String, legacyPaths: [String]) -> String? {
        if let current = read(account: account) { return current }

        for path in legacyPaths {
            guard let value = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Never delete plaintext until secure write + read-back both succeed.
            guard write(trimmed, account: account),
                  read(account: account) == trimmed else {
                return trimmed
            }

            for legacyPath in legacyPaths {
                try? FileManager.default.removeItem(atPath: legacyPath)
            }
            return trimmed
        }
        return nil
    }
}

import Foundation
import Security

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case readFailed
    case deleteFailed(OSStatus)
}

/// Cookie storage that uses UserDefaults for development builds (no code signature = keychain prompts)
/// and Keychain for signed production builds.
struct KeychainManager {
    private static let service = "com.emberbar.session-cookie"
    private static let account = "claude-session"
    private static let defaultsKey = "emberbar-session-cookie"

    // Use Keychain only if the app has a bundle identifier (signed/packaged build)
    private static var useKeychain: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleIdentifier != ""
    }

    static func saveCookie(_ cookie: String) throws {
        if useKeychain {
            try saveToKeychain(cookie)
        } else {
            UserDefaults.standard.set(cookie, forKey: defaultsKey)
        }
    }

    static func loadCookie() -> String? {
        if useKeychain {
            return loadFromKeychain()
        } else {
            // Try UserDefaults first, fall back to Keychain (migration)
            if let cookie = UserDefaults.standard.string(forKey: defaultsKey) {
                return cookie
            }
            return loadFromKeychain()
        }
    }

    static func deleteCookie() throws {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        if useKeychain {
            try deleteFromKeychain()
        }
    }

    static func hasCookie() -> Bool {
        loadCookie() != nil
    }

    // MARK: - Keychain Operations (for signed builds)

    private static func saveToKeychain(_ cookie: String) throws {
        let data = Data(cookie.utf8)

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func loadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private static func deleteFromKeychain() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

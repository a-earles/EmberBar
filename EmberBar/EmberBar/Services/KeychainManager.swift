import Foundation
import Security

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case readFailed
    case deleteFailed(OSStatus)
}

/// Cookie storage: uses UserDefaults in DEBUG builds (avoids keychain prompts on every rebuild)
/// and macOS Keychain in release/production builds.
struct KeychainManager {
    private static let service = "com.emberbar.session-cookie"
    private static let account = "claude-session"
    private static let defaultsKey = "emberbar-session-cookie"

    #if DEBUG
    // Development: UserDefaults only — never touch Keychain (avoids password prompts on rebuild)
    static func saveCookie(_ cookie: String) throws {
        UserDefaults.standard.set(cookie, forKey: defaultsKey)
    }

    static func loadCookie() -> String? {
        UserDefaults.standard.string(forKey: defaultsKey)
    }

    static func deleteCookie() throws {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
    #else
    // Production: use Keychain with ThisDeviceOnly
    static func saveCookie(_ cookie: String) throws {
        try saveToKeychain(cookie)
    }

    static func loadCookie() -> String? {
        // One-time migration from UserDefaults to Keychain
        if let legacy = UserDefaults.standard.string(forKey: defaultsKey) {
            try? saveToKeychain(legacy)
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
        return loadFromKeychain()
    }

    static func deleteCookie() throws {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        try deleteFromKeychain()
    }
    #endif

    static func hasCookie() -> Bool {
        loadCookie() != nil
    }

    // MARK: - Keychain Operations

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
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
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

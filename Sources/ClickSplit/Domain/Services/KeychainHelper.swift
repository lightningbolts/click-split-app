import Foundation
import Security

/// Secure storage helper using the Apple Keychain.
public enum KeychainHelper {
    private static let service = "com.clickplatforms.split"
    private static let tokenAccount = "authToken"
    private static let userAccount = "activeUserId"

    public static func saveToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        save(key: tokenAccount, data: data)
    }

    public static func loadToken() -> String? {
        guard let data = load(key: tokenAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func saveUserId(_ id: UUID) {
        guard let data = id.uuidString.data(using: .utf8) else { return }
        save(key: userAccount, data: data)
    }

    public static func loadUserId() -> UUID? {
        guard let data = load(key: userAccount),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return UUID(uuidString: string)
    }

    public static func clear() {
        delete(key: tokenAccount)
        delete(key: userAccount)
    }

    // ────────────────── Internal Keychain Operations ──────────────────

    private static let lock = NSLock()
    nonisolated(unsafe) private static var inMemoryFallback: [String: Data] = [:]

    private static func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        lock.lock()
        defer { lock.unlock() }
        if status != errSecSuccess {
            inMemoryFallback[key] = data
        } else {
            inMemoryFallback.removeValue(forKey: key)
        }
    }

    private static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return data
        }
        lock.lock()
        defer { lock.unlock() }
        return inMemoryFallback[key]
    }

    private static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        lock.lock()
        defer { lock.unlock() }
        inMemoryFallback.removeValue(forKey: key)
    }
}

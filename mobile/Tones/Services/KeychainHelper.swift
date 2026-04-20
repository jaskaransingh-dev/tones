import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()

    private let service = "com.tones.app"
    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"
    private let userKey = "currentUser"
    private let demoIdKey = "demoId"

    func saveSession(_ session: TonesSession) throws {
        try save(session.accessToken, key: accessTokenKey)
        try save(session.refreshToken, key: refreshTokenKey)
    }

    func getAccessToken() -> String? {
        return get(key: accessTokenKey)
    }

    func getRefreshToken() -> String? {
        return get(key: refreshTokenKey)
    }

    func saveUser(_ user: TonesUser) throws {
        let data = try JSONEncoder().encode(user)
        try save(String(data: data, encoding: .utf8) ?? "", key: userKey)
    }

    func getUser() -> TonesUser? {
        guard let data = get(key: userKey),
              let userData = data.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TonesUser.self, from: userData)
    }

    func clear() {
        delete(key: accessTokenKey)
        delete(key: refreshTokenKey)
        delete(key: userKey)
    }

    func saveDemoId(_ id: String) throws {
        try save(id, key: demoIdKey)
    }

    func getDemoId() -> String? {
        return get(key: demoIdKey)
    }

    func clearDemoId() {
        delete(key: demoIdKey)
    }

    func clearAll() {
        clear()
        clearDemoId()
    }

    private func save(_ value: String, key: String) throws {
        let data = value.data(using: .utf8)!

        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
    }

    private func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error, LocalizedError {
    case status(OSStatus)

    var errorDescription: String? {
        switch self {
        case .status(let status):
            return "Keychain error: \(status)"
        }
    }

    init(status: OSStatus) {
        self = .status(status)
    }
}
// ServerConfig.swift — server address + token storage (Keychain-backed).

import Foundation
import Security

struct ServerConfig: Equatable {
    /// e.g. http://192.168.1.10:3878
    var baseURL: String
    var token: String

    var normalizedBaseURL: String {
        var s = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "" }
        if !s.hasPrefix("http://") && !s.hasPrefix("https://") {
            s = "http://" + s
        }
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    var isValid: Bool {
        let u = normalizedBaseURL
        return u.hasPrefix("http") && URL(string: u) != nil && !token.isEmpty
    }
}

/// Small Keychain wrapper for the connection profile.
enum ServerConfigStore {
    private static let service = "com.dshremote.app"
    private static let urlKey = "server.url"
    private static let tokenKey = "server.token"

    static var config: ServerConfig? {
        get {
            if let url = read(urlKey), let token = read(tokenKey) {
                return ServerConfig(baseURL: url, token: token)
            }
            // Debug/injection fallback: UserDefaults (e.g. `simctl spawn ... defaults write`).
            let defaults = UserDefaults.standard
            if let url = defaults.string(forKey: urlKey), let token = defaults.string(forKey: tokenKey) {
                return ServerConfig(baseURL: url, token: token)
            }
            return nil
        }
        set {
            if let newValue {
                write(urlKey, newValue.normalizedBaseURL)
                write(tokenKey, newValue.token)
            } else {
                delete(urlKey)
                delete(tokenKey)
            }
        }
    }

    private static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ key: String, _ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    private static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

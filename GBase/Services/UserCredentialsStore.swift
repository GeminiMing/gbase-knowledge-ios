import Foundation
import Security

/// Stores user credentials (email and password) in Keychain
public protocol UserCredentialsStoreType {
    func saveCredentials(email: String, password: String) async throws
    func loadCredentials() async throws -> (email: String, password: String)?
    func removeCredentials() async throws
    func shouldRememberCredentials() -> Bool
    func setShouldRememberCredentials(_ remember: Bool)
}

public final class UserCredentialsStore: UserCredentialsStoreType {
    private let service = "com.gbase.knowledge.credentials"
    private let emailAccount = "user.email"
    private let passwordAccount = "user.password"
    private let rememberKey = "com.gbase.knowledge.rememberCredentials"

    public init() {}

    public func saveCredentials(email: String, password: String) async throws {
        try await saveToKeychain(account: emailAccount, value: email)
        try await saveToKeychain(account: passwordAccount, value: password)
    }

    public func loadCredentials() async throws -> (email: String, password: String)? {
        guard shouldRememberCredentials() else {
            return nil
        }

        guard let email = try await loadFromKeychain(account: emailAccount),
              let password = try await loadFromKeychain(account: passwordAccount) else {
            return nil
        }

        return (email, password)
    }

    public func removeCredentials() async throws {
        try await deleteFromKeychain(account: emailAccount)
        try await deleteFromKeychain(account: passwordAccount)
    }

    public func shouldRememberCredentials() -> Bool {
        UserDefaults.standard.bool(forKey: rememberKey)
    }

    public func setShouldRememberCredentials(_ remember: Bool) {
        UserDefaults.standard.set(remember, forKey: rememberKey)

        // If turning off, remove saved credentials
        if !remember {
            Task {
                try? await removeCredentials()
            }
        }
    }

    // MARK: - Private Helpers

    private func saveToKeychain(account: String, value: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw CredentialsError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status: OSStatus
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            var newQuery = query
            newQuery[kSecValueData as String] = data
            status = SecItemAdd(newQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw CredentialsError.keychainError(status)
        }
    }

    private func loadFromKeychain(account: String) async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess, let data = item as? Data else {
            throw CredentialsError.keychainError(status)
        }

        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(account: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialsError.keychainError(status)
        }
    }
}

enum CredentialsError: Error {
    case encodingFailed
    case keychainError(OSStatus)
}

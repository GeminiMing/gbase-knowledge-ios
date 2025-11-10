import Foundation
import Security

public final class KeychainTokenStore: TokenStore {
    private let service = "com.gbase.knowledge"
    private let account = "auth.session"
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init() {}

    public func save(session: AuthSession) async throws {
        print("🔐 [Keychain] Saving session to keychain...")
        print("🔐 [Keychain] Access Token: \(session.accessToken.prefix(20))...")
        print("🔐 [Keychain] Token Type: \(session.tokenType)")

        let data = try encoder.encode(session)
        print("🔐 [Keychain] Encoded session data size: \(data.count) bytes")

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
            print("🔐 [Keychain] Session exists, updating...")
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            print("🔐 [Keychain] Session doesn't exist, adding new...")
            var newQuery = query
            newQuery[kSecValueData as String] = data
            status = SecItemAdd(newQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            print("❌ [Keychain] Failed to save session. Status: \(status)")
            throw KeychainError.unhandledError(status)
        }

        print("✅ [Keychain] Session saved successfully")
    }

    public func currentSession() async throws -> AuthSession {
        print("🔐 [Keychain] Reading session from keychain...")

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
            print("⚠️ [Keychain] Session not found (user never logged in or logged out)")
            throw KeychainError.itemNotFound
        }

        guard status == errSecSuccess, let data = item as? Data else {
            print("❌ [Keychain] Failed to read session. Status: \(status)")
            throw KeychainError.unhandledError(status)
        }

        print("🔐 [Keychain] Session data retrieved, size: \(data.count) bytes")

        do {
            let session = try decoder.decode(AuthSession.self, from: data)
            print("✅ [Keychain] Session decoded successfully")
            print("🔐 [Keychain] Access Token: \(session.accessToken.prefix(20))...")
            print("🔐 [Keychain] Token Type: \(session.tokenType)")
            return session
        } catch {
            print("❌ [Keychain] Failed to decode session: \(error)")
            throw KeychainError.decodingFailed(error)
        }
    }

    public func removeSession() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }
}

enum KeychainError: Error {
    case itemNotFound
    case decodingFailed(Error)
    case unhandledError(OSStatus)
}


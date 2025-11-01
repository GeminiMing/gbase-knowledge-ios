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
        let data = try encoder.encode(session)
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
            throw KeychainError.unhandledError(status)
        }
    }

    public func currentSession() async throws -> AuthSession {
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
            throw KeychainError.itemNotFound
        }

        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.unhandledError(status)
        }

        do {
            return try decoder.decode(AuthSession.self, from: data)
        } catch {
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


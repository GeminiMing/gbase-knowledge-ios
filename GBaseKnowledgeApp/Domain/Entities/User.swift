import Foundation

public struct User: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let email: String
    public let defaultCompanyId: String
    public let language: String
    public let enabled: Bool
    public let authorityCodes: [String]

    public init(id: String,
                name: String,
                email: String,
                defaultCompanyId: String,
                language: String,
                enabled: Bool,
                authorityCodes: [String]) {
        self.id = id
        self.name = name
        self.email = email
        self.defaultCompanyId = defaultCompanyId
        self.language = language
        self.enabled = enabled
        self.authorityCodes = authorityCodes
    }
}

public struct UserCompany: Codable, Equatable {
    public let id: String
    public let companyId: String
    public let tenantId: Int?
    public let userName: String
    public let enabled: Bool
    public let activated: Bool

    public init(id: String,
                companyId: String,
                tenantId: Int?,
                userName: String,
                enabled: Bool,
                activated: Bool) {
        self.id = id
        self.companyId = companyId
        self.tenantId = tenantId
        self.userName = userName
        self.enabled = enabled
        self.activated = activated
    }
}

public struct UserProfile: Codable, Equatable {
    public let id: String
    public let lang: String
    public let enabled: Bool

    public init(id: String, lang: String, enabled: Bool) {
        self.id = id
        self.lang = lang
        self.enabled = enabled
    }
}

public struct AuthSession: Codable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let tokenType: String

    public init(accessToken: String,
                refreshToken: String,
                expiresAt: Date,
                tokenType: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.tokenType = tokenType
    }
}


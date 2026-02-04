import Foundation

public protocol LoginUseCase {
    func execute(email: String, password: String) async throws -> AuthContext
}

public protocol RefreshTokenUseCase {
    func execute(refreshToken: String) async throws -> AuthSession
}

public protocol FetchCurrentUserUseCase {
    func execute() async throws -> AuthContext
}

public struct AuthContext {
    public let session: AuthSession
    public let user: User
    public let profile: UserProfile
    public let company: UserCompany
    public let authorityCodes: [String]
    public let hasPassword: Bool

    public init(session: AuthSession,
                user: User,
                profile: UserProfile,
                company: UserCompany,
                authorityCodes: [String],
                hasPassword: Bool) {
        self.session = session
        self.user = user
        self.profile = profile
        self.company = company
        self.authorityCodes = authorityCodes
        self.hasPassword = hasPassword
    }
}

public final class DefaultLoginUseCase: LoginUseCase {
    private let repository: AuthRepository
    private let tokenStore: TokenStore

    public init(repository: AuthRepository, tokenStore: TokenStore) {
        self.repository = repository
        self.tokenStore = tokenStore
    }

    public func execute(email: String, password: String) async throws -> AuthContext {
        let (session, user, profile, company, hasPassword) = try await repository.login(email: email, password: password)
        try await tokenStore.save(session: session)
        return AuthContext(session: session,
                            user: user,
                            profile: profile,
                            company: company,
                            authorityCodes: user.authorityCodes,
                            hasPassword: hasPassword)
    }
}

public final class DefaultRefreshTokenUseCase: RefreshTokenUseCase {
    private let repository: AuthRepository
    private let tokenStore: TokenStore

    public init(repository: AuthRepository, tokenStore: TokenStore) {
        self.repository = repository
        self.tokenStore = tokenStore
    }

    public func execute(refreshToken: String) async throws -> AuthSession {
        let session = try await repository.refreshToken(refreshToken: refreshToken)
        try await tokenStore.save(session: session)
        return session
    }
}

public final class DefaultFetchCurrentUserUseCase: FetchCurrentUserUseCase {
    private let repository: AuthRepository
    private let tokenStore: TokenStore

    public init(repository: AuthRepository, tokenStore: TokenStore) {
        self.repository = repository
        self.tokenStore = tokenStore
    }

    public func execute() async throws -> AuthContext {
        let (user, profile, company, authorityCodes, hasPassword) = try await repository.fetchCurrentUser()
        return AuthContext(session: try await tokenStore.currentSession(),
                           user: user,
                           profile: profile,
                           company: company,
                           authorityCodes: authorityCodes,
                           hasPassword: hasPassword)
    }
}

public protocol TokenStore: Sendable {
    func save(session: AuthSession) async throws
    func currentSession() async throws -> AuthSession
    func removeSession() async throws
}


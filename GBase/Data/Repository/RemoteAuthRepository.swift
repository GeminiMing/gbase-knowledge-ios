import Foundation

public final class RemoteAuthRepository: AuthRepository {
    private let client: APIClient
    private let authBaseURL: URL

    public init(client: APIClient, authBaseURL: URL) {
        self.client = client
        self.authBaseURL = authBaseURL
    }

    public func login(email: String, password: String) async throws -> (AuthSession, User, UserProfile, UserCompany, Bool) {
        let request = LoginRequestDTO(email: email, password: password)
        let endpoint = Endpoint(path: "/user/login/password",
                                method: .post,
                                requiresAuth: false,
                                baseURLOverride: authBaseURL)
        let response = try await client.send(endpoint,
                                             body: request,
                                             responseType: LoginResponseDTO.self)

        guard response.success, let data = response.data else {
            // 如果有明确的错误消息，使用它；否则返回"无效的用户名或密码"
            if let errorMessage = response.fieldErrors?.first?.message, !errorMessage.isEmpty {
                throw APIError.serverError(statusCode: 422, message: errorMessage)
            } else {
                throw APIError.invalidCredentials
            }
        }

        let session = AuthMapper.map(session: data.loginToken)
        let profile = AuthMapper.map(profile: data.userProfile)
        let user = AuthMapper.map(user: data.user,
                                  authorityCodes: data.authorityCodes,
                                  language: profile.lang)
        let company = AuthMapper.map(company: data.userCompany)
        let hasPassword = data.hasPassword ?? true
        return (session, user, profile, company, hasPassword)
    }

    public func refreshToken(refreshToken: String) async throws -> AuthSession {
        let request = RefreshTokenRequestDTO(refreshToken: refreshToken)
        let endpoint = Endpoint(path: "/user/token/refresh",
                                method: .post,
                                requiresAuth: false,
                                baseURLOverride: authBaseURL)
        let response = try await client.send(endpoint,
                                             body: request,
                                             responseType: RefreshTokenResponseDTO.self)

        guard response.success, let token = response.data?.loginToken else {
            throw APIError.serverError(statusCode: 422, message: "刷新Token失败")
        }

        return AuthMapper.map(session: token)
    }

    public func fetchCurrentUser() async throws -> (User, UserProfile, UserCompany, [String], Bool) {
        let endpoint = Endpoint(path: "/user/my",
                                method: .get,
                                baseURLOverride: authBaseURL)
        let response = try await client.send(endpoint,
                                             responseType: CurrentUserResponseDTO.self)

        guard response.success, let data = response.data else {
            throw APIError.serverError(statusCode: 422, message: "获取用户失败")
        }

        let profile = AuthMapper.map(profile: data.userProfile)
        let user = AuthMapper.map(user: data.user,
                                  authorityCodes: data.authorityCodes,
                                  language: profile.lang)
        let company = AuthMapper.map(company: data.userCompany)
        return (user, profile, company, data.authorityCodes, data.hasPassword)
    }

    public func logout() async {
        // 后端暂无显式退出接口，清除本地凭证即可
    }
}


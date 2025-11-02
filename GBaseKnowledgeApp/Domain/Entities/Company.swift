import Foundation

// MARK: - Company Models

/// 公司信息
public struct Company: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let code: String?
    public let description: String?
    public let createdAt: String?
    public let updatedAt: String?

    /// 显示名称（优先使用 name）
    public var displayName: String {
        return name
    }
}

/// 默认公司响应
struct DefaultCompanyResponse: Codable {
    let success: Bool
    let company: Company
    let userSecurity: UserSecurity
}

/// 用户安全信息
struct UserSecurity: Codable {
    let mustChangePassword: Bool
}

/// 用户权限响应
struct UserAuthorityResponse: Codable {
    let authorityCodes: [String]
}

/// 公司列表响应
struct CompaniesListResponse: Codable {
    let companies: [Company]
}

/// 切换公司响应
struct SwitchCompanyResponse: Codable {
    let success: Bool
    let loginToken: LoginToken?
    let company: Company?
    let authorityCodes: [String]?
}

/// 登录令牌
struct LoginToken: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String?
}

/// Agent 权限检查响应
struct AgentAuthCheckResponse: Codable {
    let hasPermission: Bool
}

// MARK: - Company Manager State

/// 公司管理器状态
public struct CompanyState {
    public var currentCompanyId: String?
    public var currentCompanyName: String?
    public var currentCompanyDescription: String?
    public var currentCompanyCode: String?
    public var availableCompanies: [Company] = []
    public var hasAdminConsoleAuthority: Bool = false
    public var hasAgentPermission: Bool = false
    public var needsDefaultPasswordChange: Bool = false

    /// 当前公司
    public var currentCompany: Company? {
        guard let id = currentCompanyId else { return nil }
        return availableCompanies.first { $0.id == id }
    }

    /// 是否有多个公司
    public var hasMultipleCompanies: Bool {
        return availableCompanies.count > 1
    }

    public init() {}
}

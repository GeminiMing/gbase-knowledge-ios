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
    public let tenantId: Int?
    public let enabled: Bool?

    /// 显示名称（优先使用 name）
    public var displayName: String {
        return name
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case code
        case description
        case createdAt
        case updatedAt
        case tenantId
        case enabled
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
    let userCompany: SwitchCompanyUserInfo?
    let mustChangePassword: Bool?
    let hasPassword: Bool?
    let fieldErrors: [String]?
    let userProfile: SwitchCompanyUserProfile?
    let outputParameters: [String: String]?
    
    // 为了向后兼容，提供一个计算属性来访问数据
    // 注意：计算属性不参与 Codable 编码/解码
    var data: SwitchCompanyData? {
        guard success else { return nil }
        return SwitchCompanyData(
            loginToken: loginToken,
            company: company,
            authorityCodes: authorityCodes,
            userCompany: userCompany
        )
    }
    
    // 自定义 CodingKeys 以排除计算属性
    enum CodingKeys: String, CodingKey {
        case success
        case loginToken
        case company
        case authorityCodes
        case userCompany
        case mustChangePassword
        case hasPassword
        case fieldErrors
        case userProfile
        case outputParameters
        // 注意：不包含 data，因为它是计算属性
    }
}

struct SwitchCompanyData {
    let loginToken: LoginToken?
    let company: Company?
    let authorityCodes: [String]?
    let userCompany: SwitchCompanyUserInfo?
}

struct SwitchCompanyUserProfile: Codable {
    let id: String
    let lang: String?
    let enabled: Bool?
    let createdAt: String?
    let updatedAt: String?
}

struct SwitchCompanyUserInfo: Codable {
    let id: String
    let userId: String
    let companyId: String
    let userName: String
    let tenantId: Int?
    let jobPositionId: Int?
    let actived: Bool?
    let enabled: Bool?
    let createdAt: String?
    let updatedAt: String?
}

/// 登录令牌
struct LoginToken: Codable {
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresIn: Int?
    let refreshTokenExpiresIn: Int?
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case accessTokenExpiresIn
        case refreshTokenExpiresIn
        case tokenType
    }
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

import Foundation

struct LoginRequestDTO: Encodable {
    let email: String
    let password: String
}

struct RefreshTokenRequestDTO: Encodable {
    let refreshToken: String
}

struct RefreshTokenResponseDTO: Decodable {
    let success: Bool
    let data: RefreshTokenDataDTO?
}

struct RefreshTokenDataDTO: Decodable {
    let loginToken: TokenDTO
}

struct LoginResponseDTO: Decodable {
    let success: Bool
    let fieldErrors: [APIFieldErrorDTO]?
    let data: LoginDataDTO?
}

struct LoginDataDTO: Decodable {
    let authorityCodes: [String]
    let blocked: Bool?
    let loginToken: TokenDTO
    let mustChangePassword: Bool?
    let hasPassword: Bool?
    let userCompany: UserCompanyDTO
    let user: UserDTO
    let userProfile: UserProfileDTO
}

struct APIFieldErrorDTO: Decodable {
    let field: String?
    let message: String
}

struct TokenDTO: Codable {
    let accessToken: String
    let tokenType: String
    let accessTokenExpiresIn: Int
    let refreshToken: String
    let refreshTokenExpiresIn: Int
}

struct UserDTO: Codable {
    let id: String
    let name: String
    let email: String
    let enabled: Bool
    let defaultCompanyId: String
    let createdAt: Date?
    let updatedAt: Date?
}

struct UserProfileDTO: Codable {
    let id: String
    let lang: String
    let enabled: Bool
    let createdAt: Date?
    let updatedAt: Date?
}

struct UserCompanyDTO: Codable {
    let id: String
    let userId: String?
    let companyId: String
    let tenantId: Int?
    let userName: String
    let enabled: Bool
    let actived: Bool?
    let createdAt: Date?
    let updatedAt: Date?
}

struct CurrentUserResponseDTO: Decodable {
    let success: Bool
    let user: UserDTO
    let userProfile: UserProfileDTO
    let userCompany: UserCompanyDTO
    let authorityCodes: [String]
    let hasPassword: Bool
}


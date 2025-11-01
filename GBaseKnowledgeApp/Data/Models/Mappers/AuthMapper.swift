import Foundation

struct AuthMapper {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func map(session dto: TokenDTO) -> AuthSession {
        let expiresAt = Date(timeIntervalSinceNow: TimeInterval(dto.accessTokenExpiresIn))
        return AuthSession(accessToken: dto.accessToken,
                           refreshToken: dto.refreshToken,
                           expiresAt: expiresAt,
                           tokenType: dto.tokenType)
    }

    static func map(user dto: UserDTO,
                    authorityCodes: [String],
                    language: String) -> User {
        User(id: dto.id,
             name: dto.name,
             email: dto.email,
             defaultCompanyId: dto.defaultCompanyId,
             language: language,
             enabled: dto.enabled,
             authorityCodes: authorityCodes)
    }

    static func map(profile dto: UserProfileDTO) -> UserProfile {
        UserProfile(id: dto.id, lang: dto.lang, enabled: dto.enabled)
    }

    static func map(company dto: UserCompanyDTO) -> UserCompany {
        UserCompany(id: dto.id,
                    companyId: dto.companyId,
                    tenantId: dto.tenantId,
                    userName: dto.userName,
                    enabled: dto.enabled,
                    activated: dto.actived ?? true)
    }
}


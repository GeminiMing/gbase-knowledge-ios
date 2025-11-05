import Foundation

public protocol AuthRepository {
    func login(email: String, password: String) async throws -> (AuthSession, User, UserProfile, UserCompany, Bool)
    func refreshToken(refreshToken: String) async throws -> AuthSession
    func fetchCurrentUser() async throws -> (User, UserProfile, UserCompany, [String], Bool)
    func logout() async
}


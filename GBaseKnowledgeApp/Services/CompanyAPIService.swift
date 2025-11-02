import Foundation

/// 公司 API 服务
public class CompanyAPIService {

    private let baseURL: String
    private let session: URLSession

    public init(baseURL: String = "YOUR_API_BASE_URL", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - API Methods

    /// 获取当前默认公司
    /// GET /user/my/company/default
    func getMyCompanyDefault() async throws -> DefaultCompanyResponse {
        let url = URL(string: "\(baseURL)/user/my/company/default")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addAuthHeaders()

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode(DefaultCompanyResponse.self, from: data)
    }

    /// 获取用户的所有公司列表
    /// GET /user/my/companies
    func getMyCompaniesList() async throws -> CompaniesListResponse {
        let url = URL(string: "\(baseURL)/user/my/companies")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addAuthHeaders()

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode(CompaniesListResponse.self, from: data)
    }

    /// 切换公司
    /// POST /user/my/company/default
    func switchMyCompany(companyId: String) async throws -> SwitchCompanyResponse {
        let url = URL(string: "\(baseURL)/user/my/company/default")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addAuthHeaders()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["companyId": companyId]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode(SwitchCompanyResponse.self, from: data)
    }

    /// 获取用户权限
    /// GET /user/{companyId}/authority
    func getUserAuthority(companyId: String) async throws -> UserAuthorityResponse {
        let url = URL(string: "\(baseURL)/user/\(companyId)/authority")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addAuthHeaders()

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode(UserAuthorityResponse.self, from: data)
    }

    /// 检查 Agent 权限
    /// GET /agent/auth/check
    func checkAgentAuth() async throws -> AgentAuthCheckResponse {
        let url = URL(string: "\(baseURL)/agent/auth/check")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addAuthHeaders()

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode(AgentAuthCheckResponse.self, from: data)
    }

    // MARK: - Helper Methods

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CompanyAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw CompanyAPIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - URLRequest Extension

extension URLRequest {
    /// 添加认证请求头
    mutating func addAuthHeaders() {
        // 从 UserDefaults 或 Keychain 获取 token
        if let accessToken = UserDefaults.standard.string(forKey: "accessToken") {
            setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
    }
}

// MARK: - Company API Error

enum CompanyAPIError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应无效"
        case .httpError(let statusCode):
            return "HTTP 错误: \(statusCode)"
        case .decodingError(let message):
            return "数据解析错误: \(message)"
        }
    }
}

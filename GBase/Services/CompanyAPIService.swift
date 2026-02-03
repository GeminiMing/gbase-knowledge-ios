import Foundation

/// 公司 API 服务
public class CompanyAPIService {

    private let baseURL: String
    private let session: URLSession
    private let tokenStore: TokenStore

    public init(baseURL: String = "YOUR_API_BASE_URL", session: URLSession = .shared, tokenStore: TokenStore) {
        self.baseURL = baseURL
        self.session = session
        self.tokenStore = tokenStore
        print("🔧 CompanyAPIService 初始化，baseURL: \(baseURL)")
    }

    // MARK: - API Methods

    /// 获取当前默认公司
    /// GET /user/my/company/default
    func getMyCompanyDefault() async throws -> DefaultCompanyResponse {
        // 使用 EnvironmentManager 动态获取当前环境的 authBaseURL
        let currentBaseURL = EnvironmentManager.shared.currentEnvironment.authBaseURL.absoluteString
        let url = URL(string: "\(currentBaseURL)/user/my/company/default")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Gbase-Knowledge-Mobile-App", forHTTPHeaderField: "User-Agent")
        try await request.addAuthHeaders(tokenStore: tokenStore)

        print("🌐 API 请求: GET \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)

            // 先打印响应数据（包括错误响应）
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 API 响应数据: \(jsonString)")
            }

            try validateResponse(response)

            return try JSONDecoder().decode(DefaultCompanyResponse.self, from: data)
        } catch {
            print("❌ getMyCompanyDefault 失败: \(error)")
            throw error
        }
    }

    /// 获取用户的所有公司列表
    /// GET /user/my/companies
    func getMyCompaniesList() async throws -> CompaniesListResponse {
        // 使用 EnvironmentManager 动态获取当前环境的 authBaseURL
        let currentBaseURL = EnvironmentManager.shared.currentEnvironment.authBaseURL.absoluteString
        let url = URL(string: "\(currentBaseURL)/user/my/companies")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Gbase-Knowledge-Mobile-App", forHTTPHeaderField: "User-Agent")
        try await request.addAuthHeaders(tokenStore: tokenStore)

        print("🌐 API 请求: GET \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)

            // 打印响应数据（用于调试）
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 API 响应数据: \(jsonString)")
            }

            try validateResponse(response)

            return try JSONDecoder().decode(CompaniesListResponse.self, from: data)
        } catch {
            print("❌ getMyCompaniesList 失败: \(error)")
            throw error
        }
    }

    /// 切换公司
    /// POST /user/my/company/default
    func switchMyCompany(companyId: String) async throws -> SwitchCompanyResponse {
        // 使用 EnvironmentManager 动态获取当前环境的 authBaseURL
        let currentBaseURL = EnvironmentManager.shared.currentEnvironment.authBaseURL.absoluteString
        let url = URL(string: "\(currentBaseURL)/user/my/company/default")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Gbase-Knowledge-Mobile-App", forHTTPHeaderField: "User-Agent")
        try await request.addAuthHeaders(tokenStore: tokenStore)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["companyId": companyId]
        request.httpBody = try JSONEncoder().encode(body)

        print("🌐 API 请求: POST \(url.absoluteString)")
        print("📤 请求体: \(body)")

        var responseData: Data?
        
        do {
            let (data, response) = try await session.data(for: request)
            responseData = data

            // 打印响应数据
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 API 响应数据: \(jsonString)")
            } else {
                print("⚠️ 警告: 无法将响应数据转换为字符串")
            }

            print("📡 响应数据大小: \(data.count) 字节")

            try validateResponse(response)

            print("🔄 开始解析响应 JSON...")
            let decoder = JSONDecoder()
            let decodedResponse = try decoder.decode(SwitchCompanyResponse.self, from: data)
            print("✅ JSON 解析成功")
            return decodedResponse
        } catch let decodingError as DecodingError {
            print("❌ switchMyCompany JSON 解析失败:")
            print("❌ 解码错误类型: \(decodingError)")
            if let data = responseData, let jsonString = String(data: data, encoding: .utf8) {
                print("❌ 原始响应数据: \(jsonString)")
            }
            print("❌ 详细错误信息: \(decodingError.localizedDescription)")
            throw CompanyAPIError.decodingError(message: decodingError.localizedDescription)
        } catch {
            print("❌ switchMyCompany 失败: \(error)")
            print("❌ 错误类型: \(type(of: error))")
            print("❌ 错误描述: \(error.localizedDescription)")
            throw error
        }
    }

    /// 获取用户权限
    /// GET /user/{companyId}/authority
    func getUserAuthority(companyId: String) async throws -> UserAuthorityResponse {
        // 使用 EnvironmentManager 动态获取当前环境的 authBaseURL
        let currentBaseURL = EnvironmentManager.shared.currentEnvironment.authBaseURL.absoluteString
        let url = URL(string: "\(currentBaseURL)/user/company/\(companyId)/my/authority/")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Gbase-Knowledge-Mobile-App", forHTTPHeaderField: "User-Agent")
        try await request.addAuthHeaders(tokenStore: tokenStore)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode(UserAuthorityResponse.self, from: data)
    }

    // MARK: - Helper Methods

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CompanyAPIError.invalidResponse
        }

        print("📡 HTTP 状态码: \(httpResponse.statusCode)")
        print("📡 响应 URL: \(httpResponse.url?.absoluteString ?? "未知")")

        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ HTTP 错误: 状态码 \(httpResponse.statusCode)")
            throw CompanyAPIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - URLRequest Extension

extension URLRequest {
    /// 添加认证请求头
    mutating func addAuthHeaders(tokenStore: TokenStore) async throws {
        // 从 TokenStore (Keychain) 获取 token
        if let session = try? await tokenStore.currentSession() {
            let authHeader = "Bearer \(session.accessToken)"
            setValue(authHeader, forHTTPHeaderField: "Authorization")
            print("🔑 [CompanyAPIService] Access Token: \(session.accessToken)")
            print("🔑 [CompanyAPIService] Authorization Header: \(authHeader)")
            print("🔑 [CompanyAPIService] Token 长度: \(session.accessToken.count)")
        } else {
            print("⚠️ 警告: 未找到 session token")
            throw CompanyAPIError.invalidResponse
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

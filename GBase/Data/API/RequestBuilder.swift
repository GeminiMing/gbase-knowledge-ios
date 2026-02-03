import Foundation

public protocol RequestInterceptable {
    func willSend(_ request: URLRequest) async -> URLRequest
    func didReceive(_ data: Data?, response: URLResponse?) async
    func didFail(_ error: Error, request: URLRequest) async
}

public struct RequestBuilder {
    private let config: APIConfiguration
    private let tokenProvider: () async throws -> AuthSession?

    public init(config: APIConfiguration,
                tokenProvider: @escaping () async throws -> AuthSession?) {
        self.config = config
        self.tokenProvider = tokenProvider
    }

    public func makeRequest(endpoint: Endpoint,
                            body: Encodable? = nil,
                            headers: [String: String] = [:]) async throws -> URLRequest {
        // 优先使用 EnvironmentManager 中的环境，支持动态切换
        let currentEnvironment = EnvironmentManager.shared.currentEnvironment
        let baseURL = endpoint.baseURLOverride ?? currentEnvironment.baseURL
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: endpoint.timeout)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "Bench-X-JsonOutputResult-Data")
        request.setValue("Gbase-Knowledge-Mobile-App", forHTTPHeaderField: "User-Agent")

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if endpoint.requiresAuth, let session = try await tokenProvider() {
            let authHeader = "\(session.tokenType) \(session.accessToken)"
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            print("🔑 [RequestBuilder] Access Token: \(session.accessToken)")
            print("🔑 [RequestBuilder] Authorization Header: \(authHeader)")
        }

        if let body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            do {
                request.httpBody = try encoder.encode(AnyEncodable(body))
            } catch {
                throw APIError.encodingFailed(error)
            }
        }

        return request
    }
}

private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        self.encodeClosure = value.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}


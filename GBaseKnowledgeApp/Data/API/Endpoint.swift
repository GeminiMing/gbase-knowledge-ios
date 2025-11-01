import Foundation

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

public struct Endpoint {
    public let path: String
    public let method: HTTPMethod
    public let queryItems: [URLQueryItem]
    public let requiresAuth: Bool
    public let timeout: TimeInterval
    public let baseURLOverride: URL?

    public init(path: String,
                method: HTTPMethod = .get,
                queryItems: [URLQueryItem] = [],
                requiresAuth: Bool = true,
                timeout: TimeInterval = 300,
                baseURLOverride: URL? = nil) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.requiresAuth = requiresAuth
        self.timeout = timeout
        self.baseURLOverride = baseURLOverride
    }
}


import Foundation

public struct APIConfiguration: Sendable {
    public enum Environment: String {
        case development
        case production

        public var baseURL: URL {
            switch self {
            case .development:
                return URL(string: "https://hub-dev.gbase.ai/core-api")!
            case .production:
                return URL(string: "https://hub.gbase.ai/core-api")!
            }
        }

        public var authBaseURL: URL {
            switch self {
            case .development:
                return URL(string: "https://hub-dev.gbase.ai/ogs-api")!
            case .production:
                return URL(string: "https://hub.gbase.ai/ogs-api")!
            }
        }

        public var hubBaseURL: URL {
            switch self {
            case .development:
                return URL(string: "https://hub-dev.gbase.ai")!
            case .production:
                return URL(string: "https://hub.gbase.ai")!
            }
        }
        
        public var displayName: String {
            switch self {
            case .development:
                return "开发环境"
            case .production:
                return "生产环境"
            }
        }
    }

    public let environment: Environment
    public let sessionConfiguration: URLSessionConfiguration

    public init(environment: Environment,
                sessionConfiguration: URLSessionConfiguration = .default) {
        self.environment = environment
        self.sessionConfiguration = sessionConfiguration
    }
}


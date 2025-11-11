import Foundation

public struct APIConfiguration: Sendable {
    public enum Environment: String {
        case development
        case production

        public var baseURL: URL {
            switch self {
            case .development:
                return URL(string: "https://core-api-dev.gbase.ai")!
            case .production:
                return URL(string: "https://core-api.gbase.ai")!
            }
        }

        public var authBaseURL: URL {
            switch self {
            case .development:
                return URL(string: "https://ogs-api-dev.gbase.ai")!
            case .production:
                return URL(string: "https://ogs-api.gbase.ai")!
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
    }

    public let environment: Environment
    public let sessionConfiguration: URLSessionConfiguration

    public init(environment: Environment,
                sessionConfiguration: URLSessionConfiguration = .default) {
        self.environment = environment
        self.sessionConfiguration = sessionConfiguration
    }
}


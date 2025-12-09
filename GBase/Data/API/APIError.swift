import Foundation

public enum APIError: Error, LocalizedError, Equatable {
    case invalidURL
    case decodingFailed(Error)
    case encodingFailed(Error)
    case unauthorized
    case forbidden
    case ipBlocked
    case notFound
    case serverError(statusCode: Int, message: String)
    case invalidCredentials
    case networkUnavailable
    case timeout
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return LocalizedStringKey.errorInvalidURL.localized
        case .decodingFailed(let error):
            return String(format: LocalizedStringKey.errorDecodingFailed.localized, error.localizedDescription)
        case .encodingFailed(let error):
            return String(format: LocalizedStringKey.errorEncodingFailed.localized, error.localizedDescription)
        case .unauthorized:
            return LocalizedStringKey.errorUnauthorized.localized
        case .forbidden:
            return LocalizedStringKey.errorForbidden.localized
        case .ipBlocked:
            return LocalizedStringKey.errorIpBlocked.localized
        case .notFound:
            return LocalizedStringKey.errorNotFound.localized
        case .serverError(let statusCode, let message):
            // 如果消息已经是友好的错误消息（不包含HTML标签），直接返回
            if !message.contains("<") && !message.contains("<!DOCTYPE") {
                return "\(LocalizedStringKey.errorServerErrorDefault.localized): \(message)"
            }
            // 对于HTML错误响应，返回友好的错误消息
            if statusCode >= 500 {
                return LocalizedStringKey.errorServerInternalError.localized
            } else {
                return LocalizedStringKey.errorServerError.localized
            }
        case .invalidCredentials:
            return LocalizedStringKey.loginInvalidCredentials.localized
        case .networkUnavailable:
            return LocalizedStringKey.errorNetworkUnavailable.localized
        case .timeout:
            return LocalizedStringKey.errorTimeout.localized
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    // Implement Equatable
    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.ipBlocked, .ipBlocked),
             (.notFound, .notFound),
             (.networkUnavailable, .networkUnavailable),
             (.timeout, .timeout):
            return true
        case (.serverError(let lhsCode, let lhsMsg), .serverError(let rhsCode, let rhsMsg)):
            return lhsCode == rhsCode && lhsMsg == rhsMsg
        case (.invalidCredentials, .invalidCredentials):
            return true
        case (.decodingFailed(let lhsError), .decodingFailed(let rhsError)),
             (.encodingFailed(let lhsError), .encodingFailed(let rhsError)),
             (.unknown(let lhsError), .unknown(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}



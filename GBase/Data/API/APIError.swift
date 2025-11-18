import Foundation

public enum APIError: Error, LocalizedError, Equatable {
    case invalidURL
    case decodingFailed(Error)
    case encodingFailed(Error)
    case unauthorized
    case forbidden
    case notFound
    case serverError(statusCode: Int, message: String)
    case invalidCredentials
    case networkUnavailable
    case timeout
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的请求地址"
        case .decodingFailed(let error):
            return "数据解析失败: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "参数编码失败: \(error.localizedDescription)"
        case .unauthorized:
            return "未授权,请重新登录"
        case .forbidden:
            return "权限不足"
        case .notFound:
            return "资源不存在"
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
            return "网络不可用"
        case .timeout:
            return "请求超时"
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



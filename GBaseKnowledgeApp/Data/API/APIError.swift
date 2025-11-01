import Foundation

public enum APIError: Error, LocalizedError {
    case invalidURL
    case decodingFailed(Error)
    case encodingFailed(Error)
    case unauthorized
    case forbidden
    case notFound
    case serverError(statusCode: Int, message: String)
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
        case .serverError(_, let message):
            return "服务器错误: \(message)"
        case .networkUnavailable:
            return "网络不可用"
        case .timeout:
            return "请求超时"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}


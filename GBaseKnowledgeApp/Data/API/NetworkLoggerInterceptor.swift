import Foundation

public struct NetworkLoggerInterceptor: RequestInterceptable {
    public init() {}

    public func willSend(_ request: URLRequest) async -> URLRequest {
        #if DEBUG
        if let url = request.url {
            print("➡️ [API] \(request.httpMethod ?? "??") \(url.absoluteString)")
        }
        #endif
        return request
    }

    public func didReceive(_ data: Data?, response: URLResponse?) async {
        #if DEBUG
        if let httpResponse = response as? HTTPURLResponse {
            print("✅ [API] \(httpResponse.statusCode) \(httpResponse.url?.absoluteString ?? "")")
            if let data,
               let body = String(data: data, encoding: .utf8),
               !body.isEmpty {
                print("📦 [API] Response Body:\n\(body)")
            }
        }
        #endif
    }

    public func didFail(_ error: Error, request: URLRequest) async {
        #if DEBUG
        if let url = request.url {
            print("❌ [API] \(request.httpMethod ?? "??") \(url.absoluteString) -> \(error)")
        }
        #endif
    }
}


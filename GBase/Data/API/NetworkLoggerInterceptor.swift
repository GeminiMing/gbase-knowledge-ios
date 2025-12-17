import Foundation

public struct NetworkLoggerInterceptor: RequestInterceptable {
    public init() {}

    public func willSend(_ request: URLRequest) async -> URLRequest {
        #if DEBUG
        if let url = request.url {
            print("➡️ [API] \(request.httpMethod ?? "??") \(url.absoluteString)")
            
            // 打印请求头
            if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
                print("📋 [API] Request Headers:")
                for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                    // 隐藏敏感信息
                    if key.lowercased() == "authorization" {
                        let tokenPreview = value.prefix(20) + "..."
                        print("   \(key): \(tokenPreview)")
                    } else {
                        print("   \(key): \(value)")
                    }
                }
            }
            
            // 打印请求体（如果有）
            if let httpBody = request.httpBody {
                if let bodyString = String(data: httpBody, encoding: .utf8), !bodyString.isEmpty {
                    // 尝试格式化 JSON
                    if let jsonObject = try? JSONSerialization.jsonObject(with: httpBody),
                       let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        print("📤 [API] Request Body (JSON):\n\(jsonString)")
                    } else {
                        // 如果不是 JSON，直接打印字符串
                        let preview = bodyString.count > 500 ? String(bodyString.prefix(500)) + "..." : bodyString
                        print("📤 [API] Request Body:\n\(preview)")
                    }
                } else {
                    print("📤 [API] Request Body: (Binary data, \(httpBody.count) bytes)")
                }
            } else if request.httpMethod == "POST" || request.httpMethod == "PUT" {
                print("📤 [API] Request Body: (Empty)")
            }
        }
        #endif
        return request
    }

    public func didReceive(_ data: Data?, response: URLResponse?) async {
        #if DEBUG
        if let httpResponse = response as? HTTPURLResponse {
            print("✅ [API] \(httpResponse.statusCode) \(httpResponse.url?.absoluteString ?? "")")
            
            // 打印响应头
            if !httpResponse.allHeaderFields.isEmpty {
                print("📋 [API] Response Headers:")
                for (key, value) in httpResponse.allHeaderFields.sorted(by: { 
                    String(describing: $0.key) < String(describing: $1.key) 
                }) {
                    print("   \(key): \(value)")
                }
            }
            
            // 打印响应体
            if let data, !data.isEmpty {
                // 尝试格式化 JSON
                if let jsonObject = try? JSONSerialization.jsonObject(with: data),
                   let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("📦 [API] Response Body (JSON):\n\(jsonString)")
                } else if let bodyString = String(data: data, encoding: .utf8), !bodyString.isEmpty {
                    // 如果响应体太大，只显示前 1000 个字符
                    let preview = bodyString.count > 1000 ? String(bodyString.prefix(1000)) + "\n...(truncated, total: \(bodyString.count) chars)" : bodyString
                    print("📦 [API] Response Body:\n\(preview)")
                } else {
                    print("📦 [API] Response Body: (Binary data, \(data.count) bytes)")
                }
            } else {
                print("📦 [API] Response Body: (Empty)")
            }
        }
        #endif
    }

    public func didFail(_ error: Error, request: URLRequest) async {
        #if DEBUG
        if let url = request.url {
            print("❌ [API] \(request.httpMethod ?? "??") \(url.absoluteString) -> \(error)")
            if let httpBody = request.httpBody,
               let bodyString = String(data: httpBody, encoding: .utf8), !bodyString.isEmpty {
                let preview = bodyString.count > 200 ? String(bodyString.prefix(200)) + "..." : bodyString
                print("📤 [API] Failed Request Body:\n\(preview)")
            }
        }
        #endif
    }
}


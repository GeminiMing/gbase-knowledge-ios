import Foundation

public protocol RecordingUploadServiceType {
    func uploadRecording(meetingId: String,
                         fileURL: URL,
                         actualStartAt: Date,
                         actualEndAt: Date,
                         fileType: String,
                         fromType: String,
                         customName: String?,
                         progressHandler: @escaping (Double) -> Void) async throws -> UploadApplication
}

public final class RecordingUploadService: RecordingUploadServiceType {
    private let fileStorageService: FileStorageService
    private let session: URLSession
    private let config: APIConfiguration
    private let tokenProvider: () async throws -> AuthSession?

    public init(fileStorageService: FileStorageService,
                config: APIConfiguration,
                tokenProvider: @escaping () async throws -> AuthSession?,
                session: URLSession = .shared) {
        self.fileStorageService = fileStorageService
        self.config = config
        self.tokenProvider = tokenProvider
        self.session = session
    }

    public func uploadRecording(meetingId: String,
                                fileURL: URL,
                                actualStartAt: Date,
                                actualEndAt: Date,
                                fileType: String = "COMPLETE_RECORDING_FILE",
                                fromType: String = "GBASE",
                                customName: String? = nil,
                                progressHandler: @escaping (Double) -> Void) async throws -> UploadApplication {
        // Use custom name if provided, otherwise use filename
        let name: String
        if let customName = customName, !customName.isEmpty {
            name = customName
        } else {
            name = fileURL.deletingPathExtension().lastPathComponent
        }

        let fileData = try Data(contentsOf: fileURL)
        
        // Convert meetingId to Int
        guard let meetingIdInt = Int(meetingId) else {
            throw APIError.serverError(statusCode: 400, message: "Invalid meeting ID")
        }
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var body = Data()
        
        // Add form fields
        func appendField(_ fieldName: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fieldName)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Send fields: meetingId, fileType, sourcePlatformInfo, file
        appendField("meetingId", String(meetingIdInt))
        appendField("fileType", fileType)
        appendField("sourcePlatformInfo", Bundle.sourcePlatformInfo)
        
        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        // Use the custom name for the filename parameter if available, otherwise use fileURL.lastPathComponent
        let fileName = customName?.isEmpty == false ? (customName! + "." + fileURL.pathExtension) : fileURL.lastPathComponent
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Create request
        // 使用 EnvironmentManager 动态获取当前环境的 baseURL，支持环境切换
        let currentEnvironment = EnvironmentManager.shared.currentEnvironment
        let baseURL = currentEnvironment.baseURL
        guard let url = URL(string: baseURL.absoluteString + "/meeting/recording/fileUpload") else {
            throw APIError.invalidURL
        }
        
        // Upload with progress tracking
        // Create temporary file for upload
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try body.write(to: tempURL)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        var request = URLRequest(url: url, timeoutInterval: 300)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "Bench-X-JsonOutputResult-Data")
        request.setValue("Gbase-Knowledge-Mobile-App", forHTTPHeaderField: "User-Agent")
        // Note: Do not set httpBody when using upload(for:fromFile:)
        // The body will be read from the file
        
        // Add auth token
        if let session = try await tokenProvider() {
            let authHeader = "\(session.tokenType) \(session.accessToken)"
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            print("🔑 [RecordingUploadService] Access Token: \(session.accessToken)")
            print("🔑 [RecordingUploadService] Authorization Header: \(authHeader)")
        }
        
        // 输出完整的请求头信息
        print("📤 [RecordingUploadService] ========== 开始上传录音 ==========")
        print("📤 [RecordingUploadService] URL: \(url.absoluteString)")
        print("📤 [RecordingUploadService] HTTP Method: \(request.httpMethod ?? "未知")")
        print("📤 [RecordingUploadService] 请求头:")
        if let allHeaders = request.allHTTPHeaderFields {
            for (key, value) in allHeaders.sorted(by: { $0.key < $1.key }) {
                if key == "Authorization" {
                    print("📤 [RecordingUploadService]   \(key): \(value)")
                } else {
                    print("📤 [RecordingUploadService]   \(key): \(value)")
                }
            }
        }
        print("📤 [RecordingUploadService] 文件大小: \(body.count) 字节")
        print("📤 [RecordingUploadService] 文件名: \(fileName)")
        print("📤 [RecordingUploadService] Meeting ID: \(meetingIdInt)")
        print("📤 [RecordingUploadService] File Type: \(fileType)")
        print("📤 [RecordingUploadService] Source Platform Info: \(Bundle.sourcePlatformInfo)")
        print("📤 [RecordingUploadService] ========================================")
        
        // Create URLSession with delegate for progress tracking
        // Use the same configuration as the provided session
        let sessionConfig = session.configuration
        let progressDelegate = UploadProgressDelegate(progressHandler: progressHandler, totalBytes: body.count)
        let sessionWithDelegate = URLSession(configuration: sessionConfig, delegate: progressDelegate, delegateQueue: nil)
        
        progressHandler(0)
        let (data, response) = try await sessionWithDelegate.upload(for: request, fromFile: tempURL)
        
        sessionWithDelegate.invalidateAndCancel()
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidURL
        }
        
        // Check if response is JSON before decoding
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        let isJSON = contentType.contains("application/json") || contentType.contains("text/json")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode error response if it's JSON
            if isJSON, let errorResponse = try? JSONDecoder().decode(FileUploadResponseDTO.self, from: data) {
                let errorMessage = errorResponse.fieldErrors?.first?.message
                    ?? errorResponse.error?.message
                    ?? errorResponse.data?.message
                    ?? LocalizedStringKey.errorUploadFailed.localized
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            // If not JSON, try to extract error message from response
            if let errorString = String(data: data, encoding: .utf8), !errorString.isEmpty {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorString)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: LocalizedStringKey.errorUploadFailed.localized)
        }
        
        // Decode success response - check if it's JSON first
        guard isJSON else {
            // If not JSON, try to extract message from response
            if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Unexpected response format: \(responseString)")
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: LocalizedStringKey.errorUploadFailed.localized)
        }
        
        let uploadResponse = try JSONDecoder().decode(FileUploadResponseDTO.self, from: data)
        guard uploadResponse.success else {
            let errorMessage = uploadResponse.fieldErrors?.first?.message
                ?? uploadResponse.error?.message
                ?? LocalizedStringKey.errorUploadFailed.localized
            throw APIError.serverError(statusCode: 422, message: errorMessage)
        }
        
        progressHandler(100)
        
        // Return a dummy UploadApplication for compatibility
        // The new API doesn't return upload URI, so we create a minimal response
        return UploadApplication(
            id: Int(uploadResponse.data?.id ?? "0") ?? 0,
            uploadUri: url, // Dummy URL
            uuid: UUID().uuidString,
            contentType: "application/octet-stream"
        )
    }
}

private final class UploadProgressDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let progressHandler: (Double) -> Void
    private let totalBytes: Int

    init(progressHandler: @escaping (Double) -> Void, totalBytes: Int) {
        self.progressHandler = progressHandler
        self.totalBytes = totalBytes
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let expected = totalBytesExpectedToSend > 0 ? totalBytesExpectedToSend : Int64(totalBytes)
        let progress = Double(totalBytesSent) / Double(expected) * 100
        progressHandler(min(progress, 100))
    }
}


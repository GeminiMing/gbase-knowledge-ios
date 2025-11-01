import Foundation

public protocol RecordingUploadServiceType {
    func uploadRecording(meetingId: String,
                         fileURL: URL,
                         actualStartAt: Date,
                         actualEndAt: Date,
                         fileType: String,
                         fromType: String,
                         progressHandler: @escaping (Double) -> Void) async throws -> UploadApplication
}

public final class RecordingUploadService: RecordingUploadServiceType {
    private let applyUseCase: ApplyRecordingUploadUseCase
    private let finishUseCase: FinishRecordingUploadUseCase
    private let fileStorageService: FileStorageService
    private let session: URLSession

    public init(applyUseCase: ApplyRecordingUploadUseCase,
                finishUseCase: FinishRecordingUploadUseCase,
                fileStorageService: FileStorageService,
                session: URLSession = .shared) {
        self.applyUseCase = applyUseCase
        self.finishUseCase = finishUseCase
        self.fileStorageService = fileStorageService
        self.session = session
    }

    public func uploadRecording(meetingId: String,
                                fileURL: URL,
                                actualStartAt: Date,
                                actualEndAt: Date,
                                fileType: String = "COMPLETE_RECORDING_FILE",
                                fromType: String = "GBASE",
                                progressHandler: @escaping (Double) -> Void) async throws -> UploadApplication {
        let fileSize = try fileStorageService.fileSize(at: fileURL)
        let contentHash = try fileStorageService.sha256(of: fileURL)
        let name = fileURL.deletingPathExtension().lastPathComponent
        let `extension` = fileURL.pathExtension.lowercased()

        let apply = try await applyUseCase.execute(meetingId: meetingId,
                                                   fileName: name,
                                                   extension: `extension`,
                                                   contentHash: contentHash,
                                                   length: fileSize,
                                                   fileType: fileType,
                                                   fromType: fromType,
                                                   actualStartAt: actualStartAt,
                                                   actualEndAt: actualEndAt)

        var request = URLRequest(url: apply.uploadUri)
        request.httpMethod = HTTPMethod.put.rawValue
        request.setValue(apply.contentType, forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)

        progressHandler(0)
        let (_, response) = try await session.upload(for: request, from: fileData, delegate: UploadProgressDelegate(progressHandler: progressHandler, totalBytes: fileData.count))

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1, message: "S3 上传失败")
        }

        try await finishUseCase.execute(uploadId: apply.id, contentHash: contentHash)
        progressHandler(100)
        return apply
    }
}

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    private let progressHandler: (Double) -> Void
    private let totalBytes: Int

    init(progressHandler: @escaping (Double) -> Void, totalBytes: Int) {
        self.progressHandler = progressHandler
        self.totalBytes = totalBytes
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let expected = totalBytesExpectedToSend > 0 ? totalBytesExpectedToSend : Int64(totalBytes)
        let progress = Double(totalBytesSent) / Double(expected) * 100
        progressHandler(progress)
    }
}


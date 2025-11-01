import Foundation

public final class RemoteRecordingRepository: RecordingRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func applyUpload(for meetingId: String,
                            name: String,
                            extensionName: String,
                            contentHash: String,
                            length: Int64,
                            fileType: String,
                            fromType: String,
                            actualStartAt: Date,
                            actualEndAt: Date) async throws -> UploadApplication {
        let formatter = DateFormatter.uploadFormatter
        let request = UploadApplyRequestDTO(meetingId: meetingId,
                                            name: name,
                                            extensionName: extensionName,
                                            contentHash: contentHash,
                                            length: length,
                                            fileType: fileType,
                                            fromType: fromType,
                                            actualStartAt: formatter.string(from: actualStartAt),
                                            actualEndAt: formatter.string(from: actualEndAt))

        let response = try await client.send(Endpoint(path: "/meeting/recording/upload/apply", method: .post),
                                             body: request,
                                             responseType: UploadApplyResponseDTO.self)

        guard response.success, let data = response.data else {
            let message = response.fieldErrors?.first?.message
                ?? response.error?.message
                ?? "申请上传失败"
            throw APIError.serverError(statusCode: 422, message: message)
        }

        guard let uploadId = Int(data.id) else {
            throw APIError.serverError(statusCode: 500, message: "无效的上传ID")
        }

        let uuid = data.uuid ?? data.name ?? UUID().uuidString

        return UploadApplication(id: uploadId,
                                 uploadUri: data.uploadUri,
                                 uuid: uuid,
                                 contentType: data.contentType)
    }

    public func finishUpload(id: Int, contentHash: String) async throws {
        let request = UploadFinishRequestDTO(id: id, contentHash: contentHash)
        let response = try await client.send(Endpoint(path: "/meeting/recording/upload/finish", method: .post),
                                             body: request,
                                             responseType: GenericResponseDTO.self)

        guard response.success else {
            throw APIError.serverError(statusCode: 422, message: response.message ?? "确认上传失败")
        }
    }
}

private extension DateFormatter {
    static let uploadFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}


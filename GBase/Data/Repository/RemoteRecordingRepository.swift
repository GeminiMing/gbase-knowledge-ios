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
            // Get error message and map specific error types to localized messages
            let errorMessage = response.fieldErrors?.first?.message
                ?? response.error?.message
                ?? ""
            let errorName = response.error?.name ?? ""

            // Map specific error types to user-friendly localized messages
            let localizedMessage: String
            if errorName == "FILE_TYPE_NOT_SUPPORT" {
                localizedMessage = LocalizedStringKey.errorFileTypeNotSupported.localized
            } else if !errorMessage.isEmpty {
                // If we have a raw error message, use generic upload failed message
                localizedMessage = LocalizedStringKey.errorUploadFailed.localized
            } else {
                // Fallback to generic upload failed message
                localizedMessage = LocalizedStringKey.errorUploadFailed.localized
            }

            throw APIError.serverError(statusCode: 422, message: localizedMessage)
        }

        guard let uploadId = Int(data.id) else {
            throw APIError.serverError(statusCode: 500, message: LocalizedStringKey.errorUploadFailed.localized)
        }

        guard let uploadUri = data.uploadUri else {
            throw APIError.serverError(statusCode: 500, message: LocalizedStringKey.errorUploadFailed.localized)
        }

        guard let contentType = data.contentType else {
            throw APIError.serverError(statusCode: 500, message: LocalizedStringKey.errorUploadFailed.localized)
        }

        let uuid = data.uuid ?? data.name ?? UUID().uuidString

        return UploadApplication(id: uploadId,
                                 uploadUri: uploadUri,
                                 uuid: uuid,
                                 contentType: contentType)
    }

    public func finishUpload(id: Int, contentHash: String) async throws {
        let request = UploadFinishRequestDTO(id: id, contentHash: contentHash)
        let response = try await client.send(Endpoint(path: "/meeting/recording/upload/finish", method: .post),
                                             body: request,
                                             responseType: GenericResponseDTO.self)

        guard response.success else {
            throw APIError.serverError(statusCode: 422, message: response.message ?? LocalizedStringKey.errorUploadFailed.localized)
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


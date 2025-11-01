import Foundation

public protocol RecordingRepository {
    func applyUpload(for meetingId: String,
                     name: String,
                     extensionName: String,
                     contentHash: String,
                     length: Int64,
                     fileType: String,
                     fromType: String,
                     actualStartAt: Date,
                     actualEndAt: Date) async throws -> UploadApplication

    func finishUpload(id: Int, contentHash: String) async throws
}

public struct UploadApplication: Codable {
    public let id: Int
    public let uploadUri: URL
    public let uuid: String
    public let contentType: String

    public init(id: Int, uploadUri: URL, uuid: String, contentType: String) {
        self.id = id
        self.uploadUri = uploadUri
        self.uuid = uuid
        self.contentType = contentType
    }
}


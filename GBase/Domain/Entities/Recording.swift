import Foundation

public enum UploadStatus: String, Codable, CaseIterable {
    case pending
    case uploading
    case completed
    case failed

    public var displayName: String {
        switch self {
        case .pending:
            return LocalizedStringKey.uploadStatusPending.localized
        case .uploading:
            return LocalizedStringKey.uploadStatusUploading.localized
        case .completed:
            return LocalizedStringKey.uploadStatusCompleted.localized
        case .failed:
            return LocalizedStringKey.uploadStatusFailed.localized
        }
    }
}

public struct Recording: Identifiable, Codable, Equatable {
    public let id: String
    public let meetingId: String
    public let projectId: String
    public let fileName: String
    public let localFilePath: String
    public let fileSize: Int64
    public let duration: Double
    public let contentHash: String?
    public let uploadStatus: UploadStatus
    public let uploadProgress: Double
    public let uploadId: Int?
    public let createdAt: Date
    public let actualStartAt: Date?
    public let actualEndAt: Date?

    public init(id: String,
                meetingId: String,
                projectId: String,
                fileName: String,
                localFilePath: String,
                fileSize: Int64,
                duration: Double,
                contentHash: String?,
                uploadStatus: UploadStatus,
                uploadProgress: Double,
                uploadId: Int?,
                createdAt: Date,
                actualStartAt: Date?,
                actualEndAt: Date?) {
        self.id = id
        self.meetingId = meetingId
        self.projectId = projectId
        self.fileName = fileName
        self.localFilePath = localFilePath
        self.fileSize = fileSize
        self.duration = duration
        self.contentHash = contentHash
        self.uploadStatus = uploadStatus
        self.uploadProgress = uploadProgress
        self.uploadId = uploadId
        self.createdAt = createdAt
        self.actualStartAt = actualStartAt
        self.actualEndAt = actualEndAt
    }
}


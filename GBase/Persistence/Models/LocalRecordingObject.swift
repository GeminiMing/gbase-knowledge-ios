import Foundation
import RealmSwift

public final class LocalRecordingObject: Object {
    @Persisted(primaryKey: true) public var id: String
    @Persisted public var meetingId: String?        // Optional for draft recordings
    @Persisted public var projectId: String?        // Optional for draft recordings
    @Persisted public var fileName: String
    @Persisted public var customName: String?       // User-defined name
    @Persisted public var filePath: String
    @Persisted public var fileSize: Int64
    @Persisted public var duration: Double
    @Persisted public var contentHash: String?
    @Persisted public var uploadStatusRaw: String
    @Persisted public var uploadProgress: Double
    @Persisted public var uploadId: Int?
    @Persisted public var createdAt: Date
    @Persisted public var actualStartAt: Date?
    @Persisted public var actualEndAt: Date?

    public var uploadStatus: UploadStatus {
        get { UploadStatus(rawValue: uploadStatusRaw) ?? .pending }
        set { uploadStatusRaw = newValue.rawValue }
    }

    public var isDraft: Bool {
        return projectId == nil || meetingId == nil
    }

    public convenience init(recording: Recording) {
        self.init()
        self.id = recording.id
        self.meetingId = recording.meetingId
        self.projectId = recording.projectId
        self.fileName = recording.fileName
        self.customName = recording.customName
        self.filePath = recording.localFilePath
        self.fileSize = recording.fileSize
        self.duration = recording.duration
        self.contentHash = recording.contentHash
        self.uploadStatusRaw = recording.uploadStatus.rawValue
        self.uploadProgress = recording.uploadProgress
        self.uploadId = recording.uploadId
        self.createdAt = recording.createdAt
        self.actualStartAt = recording.actualStartAt
        self.actualEndAt = recording.actualEndAt
    }

    public func toDomain() -> Recording {
        Recording(id: id,
                  meetingId: meetingId,
                  projectId: projectId,
                  fileName: fileName,
                  customName: customName,
                  localFilePath: filePath,
                  fileSize: fileSize,
                  duration: duration,
                  contentHash: contentHash,
                  uploadStatus: uploadStatus,
                  uploadProgress: uploadProgress,
                  uploadId: uploadId,
                  createdAt: createdAt,
                  actualStartAt: actualStartAt,
                  actualEndAt: actualEndAt)
    }
}


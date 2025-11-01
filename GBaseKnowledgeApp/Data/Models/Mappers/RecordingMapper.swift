import Foundation

struct RecordingMapper {
    static func map(_ dto: RecordingDTO, meetingId: String, projectId: String) -> Recording {
        Recording(id: dto.id,
                  meetingId: meetingId,
                  projectId: projectId,
                  fileName: dto.fileName,
                  localFilePath: dto.url?.absoluteString ?? "",
                  fileSize: dto.fileSize,
                  duration: dto.duration,
                  contentHash: dto.contentHash,
                  uploadStatus: UploadStatus(rawValue: dto.uploadStatus ?? "pending") ?? .pending,
                  uploadProgress: dto.uploadProgress ?? 0,
                  uploadId: dto.uploadId,
                  createdAt: dto.createdAt ?? Date(),
                  actualStartAt: dto.actualStartAt,
                  actualEndAt: dto.actualEndAt)
    }
}


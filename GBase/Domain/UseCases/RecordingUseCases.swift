import Foundation

public protocol ApplyRecordingUploadUseCase {
    func execute(meetingId: String,
                 fileName: String,
                 `extension`: String,
                 contentHash: String,
                 length: Int64,
                 fileType: String,
                 fromType: String,
                 actualStartAt: Date,
                 actualEndAt: Date) async throws -> UploadApplication
}

public protocol FinishRecordingUploadUseCase {
    func execute(uploadId: Int, contentHash: String) async throws
}

public final class DefaultApplyRecordingUploadUseCase: ApplyRecordingUploadUseCase {
    private let repository: RecordingRepository

    public init(repository: RecordingRepository) {
        self.repository = repository
    }

    public func execute(meetingId: String,
                        fileName: String,
                        `extension`: String,
                        contentHash: String,
                        length: Int64,
                        fileType: String,
                        fromType: String,
                        actualStartAt: Date,
                        actualEndAt: Date) async throws -> UploadApplication {
        try await repository.applyUpload(for: meetingId,
                                         name: fileName,
                                         extensionName: `extension`,
                                         contentHash: contentHash,
                                         length: length,
                                         fileType: fileType,
                                         fromType: fromType,
                                         actualStartAt: actualStartAt,
                                         actualEndAt: actualEndAt)
    }
}

public final class DefaultFinishRecordingUploadUseCase: FinishRecordingUploadUseCase {
    private let repository: RecordingRepository

    public init(repository: RecordingRepository) {
        self.repository = repository
    }

    public func execute(uploadId: Int, contentHash: String) async throws {
        try await repository.finishUpload(id: uploadId, contentHash: contentHash)
    }
}


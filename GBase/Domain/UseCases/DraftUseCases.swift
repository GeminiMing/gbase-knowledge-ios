import Foundation

// MARK: - Fetch Drafts Use Case
public protocol FetchDraftsUseCase {
    func execute() throws -> [Recording]
}

public final class DefaultFetchDraftsUseCase: FetchDraftsUseCase {
    private let localStore: RecordingLocalStore

    public init(localStore: RecordingLocalStore) {
        self.localStore = localStore
    }

    public func execute() throws -> [Recording] {
        try localStore.fetchDrafts()
    }
}

// MARK: - Bind Draft to Project Use Case
public protocol BindDraftToProjectUseCase {
    func execute(recordingId: String,
                 projectId: String,
                 meetingId: String,
                 customName: String?) throws
}

public final class DefaultBindDraftToProjectUseCase: BindDraftToProjectUseCase {
    private let localStore: RecordingLocalStore

    public init(localStore: RecordingLocalStore) {
        self.localStore = localStore
    }

    public func execute(recordingId: String,
                       projectId: String,
                       meetingId: String,
                       customName: String?) throws {
        try localStore.updateRecording(id: recordingId,
                                       projectId: projectId,
                                       meetingId: meetingId,
                                       customName: customName)
    }
}

// MARK: - Update Draft Name Use Case
public protocol UpdateDraftNameUseCase {
    func execute(recordingId: String, customName: String) throws
}

public final class DefaultUpdateDraftNameUseCase: UpdateDraftNameUseCase {
    private let localStore: RecordingLocalStore

    public init(localStore: RecordingLocalStore) {
        self.localStore = localStore
    }

    public func execute(recordingId: String, customName: String) throws {
        try localStore.updateRecording(id: recordingId,
                                       projectId: nil,
                                       meetingId: nil,
                                       customName: customName)
    }
}

// MARK: - Delete Draft Use Case
public protocol DeleteDraftUseCase {
    func execute(recordingId: String) throws
}

public final class DefaultDeleteDraftUseCase: DeleteDraftUseCase {
    private let localStore: RecordingLocalStore
    private let fileStorage: FileStorageService

    public init(localStore: RecordingLocalStore, fileStorage: FileStorageService) {
        self.localStore = localStore
        self.fileStorage = fileStorage
    }

    public func execute(recordingId: String) throws {
        // Fetch the recording to get file path
        let recordings = try localStore.fetch(projectId: nil, status: nil)
        guard let recording = recordings.first(where: { $0.id == recordingId }) else { return }

        // Delete file from storage
        let fileURL = URL(fileURLWithPath: recording.localFilePath)
        try? fileStorage.removeFile(at: fileURL)

        // Remove from database
        try localStore.remove(recordingId)
    }
}

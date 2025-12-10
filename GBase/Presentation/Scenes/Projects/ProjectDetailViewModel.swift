import Foundation
import Combine
import SwiftUI

@MainActor
final class ProjectDetailViewModel: ObservableObject {
    @Published var recordings: [Recording] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var playingRecordingId: String?
    @Published var uploadingRecordingId: String?
    @Published var uploadProgress: Double = 0
    @Published var recordingToDelete: Recording?
    @Published var shouldDeleteRecording: Bool = false

    private var container: DIContainer?
    private let projectId: String

    init(projectId: String) {
        self.projectId = projectId
    }

    func configure(container: DIContainer) {
        self.container = container
        container.audioPlayerService.delegate = self
    }
    
    func cleanup() {
        // 清理资源，停止播放
        if let container = container, playingRecordingId != nil {
            container.audioPlayerService.stop()
            playingRecordingId = nil
        }
    }

    func loadRecordings() async {
        isLoading = true
        defer { isLoading = false }

        guard let container else {
            errorMessage = LocalizedStringKey.profileDependencyNotInjected.localized
            return
        }

        do {
            let fetchedRecordings = try container.recordingLocalStore.fetch(projectId: projectId, status: nil)
            // 按创建时间倒序排列,最新的在最上方
            recordings = fetchedRecordings.sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func bindAndUploadRecording(_ recording: Recording) async {
        guard let container else { return }

        uploadingRecordingId = recording.id
        uploadProgress = 0
        defer {
            uploadingRecordingId = nil
            uploadProgress = 0
        }

        do {
            // Create a meeting for this recording
            let meetingTitle = recording.displayName
            let meeting = try await container.createMeetingUseCase.execute(
                projectId: projectId,
                title: meetingTitle,
                meetingTime: recording.createdAt,
                location: nil,
                description: nil
            )

            // Bind the draft to the project and meeting
            try container.bindDraftToProjectUseCase.execute(
                recordingId: recording.id,
                projectId: projectId,
                meetingId: meeting.id,
                customName: recording.customName
            )

            // Fetch the updated recording
            let recordings = try container.recordingLocalStore.fetch(projectId: nil, status: nil)
            guard let updatedRecording = recordings.first(where: { $0.id == recording.id }) else {
                errorMessage = LocalizedStringKey.draftDetailRecordingNotFound.localized
                return
            }

            // Upload the recording
            try await uploadRecording(updatedRecording)

            // Reload recordings to show updated status
            await loadRecordings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uploadRecording(_ recording: Recording) async throws {
        guard let container else { throw APIError.networkUnavailable }
        guard let meetingId = recording.meetingId else { return }

        let fileURL = URL(fileURLWithPath: recording.localFilePath)
        let actualStart = recording.actualStartAt ?? Date()
        let actualEnd = recording.actualEndAt ?? Date()

        _ = try await container.recordingUploadService.uploadRecording(
            meetingId: meetingId,
            fileURL: fileURL,
            actualStartAt: actualStart,
            actualEndAt: actualEnd,
            fileType: "COMPLETE_RECORDING_FILE",
            fromType: "GBASE",
            customName: recording.customName,
            progressHandler: { [weak self] progress in
                Task { @MainActor in
                    self?.uploadProgress = progress
                    try? container.recordingLocalStore.update(
                        id: recording.id,
                        status: progress >= 100 ? .completed : .uploading,
                        progress: progress
                    )
                }
            }
        )

        try container.recordingLocalStore.update(id: recording.id, status: .completed, progress: 100)
    }

    func confirmDeleteRecording(_ recording: Recording) {
        recordingToDelete = recording
    }
    
    func deleteRecording(recording: Recording) async {
        guard let container else { 
            recordingToDelete = nil
            shouldDeleteRecording = false
            return 
        }
        
        // 保存要删除的录音ID和文件路径
        let recordingId = recording.id
        let filePath = recording.localFilePath
        
        do {
            if playingRecordingId == recording.id {
                container.audioPlayerService.stop()
            }

            // 先删除数据库记录
            try container.recordingLocalStore.remove(recordingId)
            
            // 再删除文件
            let fileURL = URL(fileURLWithPath: filePath)
            try container.fileStorageService.removeFile(at: fileURL)
            
            // 清空待删除的录音并刷新列表
            recordingToDelete = nil
            shouldDeleteRecording = false
            await loadRecordings()
        } catch {
            Logger.error("❌ [ProjectDetail] 删除失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            recordingToDelete = nil
            shouldDeleteRecording = false
        }
    }

    func togglePlayback(recording: Recording) {
        guard let container else { return }
        let fileURL = URL(fileURLWithPath: recording.localFilePath)

        do {
            if playingRecordingId == recording.id {
                container.audioPlayerService.stop()
            } else {
                try container.audioPlayerService.play(url: fileURL)
                playingRecordingId = recording.id
            }
        } catch {
            errorMessage = error.localizedDescription
            playingRecordingId = nil
        }
    }

    func isPlaying(recording: Recording) -> Bool {
        playingRecordingId == recording.id
    }

    func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    func formatFileSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024

        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.1f KB", kb)
        }
    }
}

extension ProjectDetailViewModel: AudioPlayerServiceDelegate {
    func playerDidStart(url: URL) {}

    func playerDidFinish() {
        playingRecordingId = nil
    }

    func playerDidFail(_ error: Error) {
        playingRecordingId = nil
        errorMessage = error.localizedDescription
    }
}

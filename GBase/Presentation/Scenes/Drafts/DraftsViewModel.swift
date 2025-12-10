import Foundation
import Combine
import SwiftUI

@MainActor
final class DraftsViewModel: ObservableObject {
    @Published var drafts: [Recording] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var playingRecordingId: String?
    @Published var fileMissingRecordingIds: Set<String> = []  // 追踪文件缺失的录音
    @Published var draftToDelete: Recording?

    private var container: DIContainer?

    init(container: DIContainer? = nil) {
        self.container = container
    }

    func configure(container: DIContainer) {
        self.container = container
        container.audioPlayerService.delegate = self
    }

    func loadDrafts() async {
        isLoading = true
        defer { isLoading = false }

        guard let container else {
            errorMessage = LocalizedStringKey.profileDependencyNotInjected.localized
            return
        }

        do {
            let fetchedDrafts = try container.fetchDraftsUseCase.execute()

            // 过滤出文件实际存在的录音，并按创建时间倒序排列
            let fileManager = FileManager.default
            let validDrafts = fetchedDrafts.filter { draft in
                let fileExists = fileManager.fileExists(atPath: draft.localFilePath)
                if !fileExists {
                    // 可以选择删除这些无效的记录
                    Task {
                        do {
                            try container.deleteDraftUseCase.execute(recordingId: draft.id)
                        } catch {
                            Logger.error("❌ [DraftsViewModel] Failed to delete draft with missing file: \(error)")
                        }
                    }
                }
                return fileExists
            }

            drafts = validDrafts.sorted { $0.createdAt > $1.createdAt }
        } catch {
            Logger.error("❌ [DraftsViewModel] 加载草稿失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func confirmDeleteDraft(_ recording: Recording) {
        draftToDelete = recording
    }
    
    func deleteDraft() async {
        guard let container, let recording = draftToDelete else { 
            draftToDelete = nil
            return 
        }

        // 保存要删除的录音ID
        let recordingId = recording.id

        do {
            if playingRecordingId == recording.id {
                container.audioPlayerService.stop()
            }

            // 执行删除
            try container.deleteDraftUseCase.execute(recordingId: recordingId)
            
            // 清空待删除的草稿并刷新列表
            draftToDelete = nil
            await loadDrafts()
        } catch {
            Logger.error("❌ [DraftsViewModel] 删除失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            draftToDelete = nil
        }
    }

    func togglePlayback(recording: Recording) {
        guard let container else { return }

        // 先检查文件是否存在
        if !checkFileExists(recording: recording) {
            errorMessage = "找不到本地录音文件。该录音可能未从 Apple Watch 完全同步，或文件已被删除。"
            print("❌ [DraftsViewModel] Cannot play - file not found: \(recording.localFilePath)")
            return
        }

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
            print("❌ [DraftsViewModel] Playback error: \(error)")
        }
    }

    func isPlaying(recording: Recording) -> Bool {
        playingRecordingId == recording.id
    }

    func isFileMissing(recording: Recording) -> Bool {
        return fileMissingRecordingIds.contains(recording.id)
    }

    func checkFileExists(recording: Recording) -> Bool {
        let fileExists = FileManager.default.fileExists(atPath: recording.localFilePath)
        if !fileExists {
            fileMissingRecordingIds.insert(recording.id)
        }
        return fileExists
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

extension DraftsViewModel: AudioPlayerServiceDelegate {
    func playerDidStart(url: URL) {}

    func playerDidFinish() {
        playingRecordingId = nil
    }

    func playerDidFail(_ error: Error) {
        playingRecordingId = nil
        errorMessage = error.localizedDescription
    }
}

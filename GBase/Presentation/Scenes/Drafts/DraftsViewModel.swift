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
    @Published var shouldDeleteDraft: Bool = false  // Flag to prevent clearing draftToDelete during deletion

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
            Logger.debug("📋 [DraftsViewModel] Loaded \(fetchedDrafts.count) drafts from database")

            // 过滤出文件实际存在的录音，并按创建时间倒序排列
            let fileManager = FileManager.default
            var validDrafts: [Recording] = []
            var invalidDraftIds: [String] = []
            
            for draft in fetchedDrafts {
                let fileExists = fileManager.fileExists(atPath: draft.localFilePath)
                if fileExists {
                    validDrafts.append(draft)
                } else {
                    // 只有在非上传状态下才删除无效记录（避免上传过程中误删）
                    if draft.uploadStatus != .uploading {
                        Logger.info("⚠️ [DraftsViewModel] Draft file missing: \(draft.id), path: \(draft.localFilePath)")
                        invalidDraftIds.append(draft.id)
                    } else {
                        // 上传中的录音即使文件暂时不存在也保留记录
                        Logger.debug("📋 [DraftsViewModel] Keeping uploading draft even if file missing: \(draft.id)")
                        validDrafts.append(draft)
                    }
                }
            }
            
            // 异步删除无效记录
            if !invalidDraftIds.isEmpty {
                Logger.debug("🗑️ [DraftsViewModel] Will delete \(invalidDraftIds.count) invalid drafts")
                Task {
                    for draftId in invalidDraftIds {
                        do {
                            try container.deleteDraftUseCase.execute(recordingId: draftId)
                            Logger.debug("✅ [DraftsViewModel] Deleted invalid draft: \(draftId)")
                        } catch {
                            Logger.error("❌ [DraftsViewModel] Failed to delete draft with missing file: \(error)")
                        }
                    }
                }
            }

            drafts = validDrafts.sorted { $0.createdAt > $1.createdAt }
            Logger.debug("✅ [DraftsViewModel] Displaying \(drafts.count) valid drafts")
        } catch {
            Logger.error("❌ [DraftsViewModel] 加载草稿失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func confirmDeleteDraft(_ recording: Recording) {
        Logger.debug("🗑️ [DraftsViewModel] confirmDeleteDraft called with recording: \(recording.id)")
        draftToDelete = recording
        Logger.debug("🗑️ [DraftsViewModel] draftToDelete set to: \(draftToDelete?.id ?? "nil")")
    }
    
    func deleteDraft(recording: Recording) async {
        Logger.debug("🗑️ [DraftsViewModel] deleteDraft called with recording: \(recording.id)")
        
        guard let container else {
            Logger.error("❌ [DraftsViewModel] Container is nil, cannot delete")
            draftToDelete = nil
            shouldDeleteDraft = false
            return
        }

        // 保存要删除的录音ID
        let recordingId = recording.id
        Logger.debug("🗑️ [DraftsViewModel] Starting delete for recording: \(recordingId)")

        // 先停止播放（如果在播放）
        if playingRecordingId == recording.id {
            Logger.debug("🗑️ [DraftsViewModel] Stopping playback for recording: \(recordingId)")
            container.audioPlayerService.stop()
            playingRecordingId = nil
        }

        do {
            Logger.debug("🗑️ [DraftsViewModel] Calling deleteDraftUseCase.execute for: \(recordingId)")
            // 执行删除
            try container.deleteDraftUseCase.execute(recordingId: recordingId)
            
            Logger.debug("✅ [DraftsViewModel] 删除成功: \(recordingId)")
            
            // 刷新列表（确保在主线程）
            Logger.debug("🔄 [DraftsViewModel] Reloading drafts list")
            await loadDrafts()
            
            // 清空待删除的草稿状态
            draftToDelete = nil
            shouldDeleteDraft = false
            Logger.debug("✅ [DraftsViewModel] Delete completed, state cleared")
        } catch {
            Logger.error("❌ [DraftsViewModel] 删除失败: \(error.localizedDescription)")
            Logger.error("❌ [DraftsViewModel] Error details: \(error)")
            errorMessage = error.localizedDescription
            draftToDelete = nil
            shouldDeleteDraft = false
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

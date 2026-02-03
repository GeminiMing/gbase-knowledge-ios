import Foundation
import Combine
import SwiftUI
import AVFoundation

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
    
    // Constants for file import
    private let maxImportFileSize: Int64 = 1 * 1024 * 1024 * 1024 // 1GB
    private let allowedImportExtensions = ["wav", "webm", "mp3", "mp4", "m4a"]

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
            
            // 打印所有草稿的详细信息
            for draft in fetchedDrafts {
                Logger.debug("📋 [DraftsViewModel] Draft: \(draft.id), fileName: \(draft.fileName), filePath: \(draft.localFilePath), customName: \(draft.customName ?? "nil")")
            }

            // 过滤出文件实际存在的录音，并按创建时间倒序排列
            let fileManager = FileManager.default
            var validDrafts: [Recording] = []
            var invalidDraftIds: [String] = []
            
            for var draft in fetchedDrafts {
                var fileExists = fileManager.fileExists(atPath: draft.localFilePath)
                
                // Robustness fix: If file not found at absolute path, try to find it in Documents/Recordings
                if !fileExists {
                    if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let potentialPath = documentsPath.appendingPathComponent("Recordings").appendingPathComponent(draft.fileName).path
                        if fileManager.fileExists(atPath: potentialPath) {
                            Logger.debug("🔄 [DraftsViewModel] Recovered file path for \(draft.id). Old: \(draft.localFilePath), New: \(potentialPath)")
                            // Update the draft object in memory (persisting to DB would be better but this fixes display)
                            draft = Recording(
                                id: draft.id,
                                meetingId: draft.meetingId,
                                projectId: draft.projectId,
                                fileName: draft.fileName,
                                customName: draft.customName,
                                localFilePath: potentialPath, // Use recovered path
                                fileSize: draft.fileSize,
                                duration: draft.duration,
                                contentHash: draft.contentHash,
                                uploadStatus: draft.uploadStatus,
                                uploadProgress: draft.uploadProgress,
                                uploadId: draft.uploadId,
                                createdAt: draft.createdAt,
                                actualStartAt: draft.actualStartAt,
                                actualEndAt: draft.actualEndAt
                            )
                            fileExists = true
                        }
                    }
                }
                
                Logger.debug("📋 [DraftsViewModel] File exists check for \(draft.id): \(fileExists) at path: \(draft.localFilePath)")
                
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
    
    // Import audio file from local storage
    func importAudioFile(url: URL) async {
        guard let container else {
            errorMessage = LocalizedStringKey.profileDependencyNotInjected.localized
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer {
            if gotAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // Check file size limit
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resources.fileSize, Int64(fileSize) > maxImportFileSize {
                errorMessage = LocalizedStringKey.recorderImportFileTooLarge.localized
                return
            }

            // Check file format
            let fileExtension = url.pathExtension.lowercased()
            if !allowedImportExtensions.contains(fileExtension) {
                errorMessage = LocalizedStringKey.recorderImportFileFormatError.localized
                return
            }

            // 1. Prepare target path
            let now = Date()
            
            // Create a unique file name for the imported file
            let originalExtension = url.pathExtension
            let fileName = "Imported-\(Int(now.timeIntervalSince1970))-\(UUID().uuidString.prefix(8)).\(originalExtension.isEmpty ? "m4a" : originalExtension)"
            
            // Get documents directory directly
            let destinationURL = try container.fileStorageService.makeRecordingURL(timestamp: now, meetingId: "draft")
                .deletingLastPathComponent()
                .appendingPathComponent(fileName)
            
            Logger.debug("🎤 [DraftsViewModel] Importing file from: \(url.path) to: \(destinationURL.path)")
            
            // 2. Copy file
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            // 3. Get file info
            let fileSize = try container.fileStorageService.fileSize(at: destinationURL)
            
            // Calculate duration
            let asset = AVURLAsset(url: destinationURL)
            let duration: Double
            if #available(iOS 16.0, *) {
                let cmTime = try await asset.load(.duration)
                duration = Double(CMTimeGetSeconds(cmTime))
            } else {
                duration = Double(CMTimeGetSeconds(asset.duration))
            }
            
            // 4. Create Recording object
            let recording = Recording(
                id: UUID().uuidString,
                meetingId: nil, // Draft has no meeting ID initially
                projectId: nil, // Draft has no project ID
                fileName: fileName,
                customName: url.deletingPathExtension().lastPathComponent, // Use original filename as custom name
                localFilePath: destinationURL.path,
                fileSize: fileSize,
                duration: duration,
                contentHash: nil,
                uploadStatus: .pending,
                uploadProgress: 0,
                uploadId: nil,
                createdAt: Date(),
                actualStartAt: now,
                actualEndAt: now.addingTimeInterval(duration)
            )
            
            // 5. Save to local store
            try container.recordingLocalStore.upsert(recording)
            Logger.debug("✅ [DraftsViewModel] Imported recording saved: \(recording.id)")
            
            // 6. Reload drafts
            await loadDrafts()
            
        } catch {
            Logger.error("❌ [DraftsViewModel] Import failed: \(error)")
            errorMessage = error.localizedDescription
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

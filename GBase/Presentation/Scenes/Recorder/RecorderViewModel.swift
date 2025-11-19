import Foundation
import Combine
import SwiftUI
import AVFoundation
import CoreMedia

@MainActor
public final class RecorderViewModel: NSObject, ObservableObject {
    public enum Status: Equatable {
        case idle
        case recording(duration: TimeInterval)
        case processing
        case uploading(progress: Double)
        case completed
    }

    @Published var status: Status = .idle
    @Published var projectOptions: [ProjectOption] = []
    @Published var selectedProjectId: String?
    @Published var selectedProjectTitle: String?
    @Published var meetingTitle: String = ""
    @Published var errorMessage: String?
    @Published private(set) var preparedMeeting: Meeting?
    @Published var localRecordings: [Recording] = []
    @Published var playingRecordingId: String?
    @Published var waveformSamples: [CGFloat]
    @Published var isDraftMode: Bool = false  // New: indicates if recording without project
    @Published var showSaveToProjectAlert: Bool = false  // Show alert after draft recording
    @Published var completedDraftRecordingId: String?  // ID of the completed draft recording
    @Published var saveToProjectSelectedProjectId: String?  // Selected project for save to project
    @Published var isBindingToProject: Bool = false  // Binding in progress

    public struct ProjectOption: Identifiable, Equatable {
        public let id: String
        public let title: String
        
        public init(id: String, title: String) {
            self.id = id
            self.title = title
        }
    }

    var container: DIContainer? {
        get { _container }
    }
    private var _container: DIContainer?
    private var recordingURL: URL?
    private var recordingStartAt: Date?
    private let waveformCapacity = 24

    override init() {
        waveformSamples = Array(repeating: 0.1, count: waveformCapacity)
        super.init()
    }

    func configure(container: DIContainer, shouldLoadProjects: Bool = true) {
        self._container = container
        container.audioRecorderService.delegate = self
        container.audioPlayerService.delegate = self
        resetWaveform()
        if shouldLoadProjects {
            Task { await loadProjects() }
            Task { await loadLocalRecordings() }
        }
    }

    func prepare(for project: Project, meeting: Meeting) {
        print("🎤 [RecorderViewModel] prepare called for project: \(project.title), meeting: \(meeting.id)")
        selectedProjectId = project.id
        selectedProjectTitle = project.title
        meetingTitle = meeting.title
        preparedMeeting = meeting
        isDraftMode = false
        print("🎤 [RecorderViewModel] isDraftMode set to: \(isDraftMode)")

        if !projectOptions.contains(where: { $0.id == project.id }) {
            projectOptions.insert(ProjectOption(id: project.id, title: project.title), at: 0)
        }

        Task { await loadLocalRecordings() }
    }

    // New: Prepare for quick recording without project
    func prepareForQuickRecording() {
        print("🎤 [RecorderViewModel] prepareForQuickRecording called")
        selectedProjectId = nil
        selectedProjectTitle = nil
        meetingTitle = ""
        preparedMeeting = nil
        isDraftMode = true
        print("🎤 [RecorderViewModel] isDraftMode set to: \(isDraftMode)")
    }

    func loadProjects() async {
        guard let container else { return }
        do {
            let map = try await container.fetchEditableProjectsUseCase.execute()
            let options = map.map { ProjectOption(id: $0.key, title: $0.value) }.sorted { $0.title < $1.title }
            projectOptions = options

            let validProjectIds = Set(options.map { $0.id })

            if let currentSelectedProjectId = selectedProjectId, !validProjectIds.contains(currentSelectedProjectId) {
                preparedMeeting = nil
                selectedProjectTitle = nil
                selectedProjectId = options.first?.id
            }

            if selectedProjectId == nil {
                selectedProjectId = options.first?.id
            }

            await pruneRecordings(for: validProjectIds)
            await loadLocalRecordings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startRecording() async {
        guard let container else {
            errorMessage = LocalizedStringKey.recorderDependencyNotInjected.localized
            return
        }

        // Allow recording without prepared meeting if in draft mode
        if !isDraftMode && preparedMeeting == nil {
            errorMessage = LocalizedStringKey.recorderMeetingNotPrepared.localized
            return
        }

        do {
            let granted = await container.audioRecorderService.requestPermission()
            guard granted else {
                errorMessage = LocalizedStringKey.recorderMicrophonePermissionDenied.localized
                return
            }

            let now = Date()
            let meetingId = isDraftMode ? "draft" : preparedMeeting?.id ?? "unknown"
            let fileURL = try container.fileStorageService.makeRecordingURL(timestamp: now, meetingId: meetingId)
            try container.audioRecorderService.startRecording(to: fileURL)

            self.recordingURL = fileURL
            self.recordingStartAt = now
            resetWaveform()
            status = .recording(duration: 0)
        } catch {
            errorMessage = error.localizedDescription
            status = .idle
        }
    }

    func stopRecording() async {
        guard let container, let fileURL = recordingURL, let startAt = recordingStartAt else {
            status = .idle
            return
        }

        container.audioRecorderService.stopRecording()
        status = .processing

        print("🎤 [RecorderViewModel] stopRecording called")
        print("🎤 [RecorderViewModel] isDraftMode: \(isDraftMode)")
        print("🎤 [RecorderViewModel] preparedMeeting: \(String(describing: preparedMeeting))")
        print("🎤 [RecorderViewModel] selectedProjectId: \(String(describing: selectedProjectId))")

        do {
            let fileSize = try container.fileStorageService.fileSize(at: fileURL)
            let duration = try await durationOfFile(at: fileURL)

            // Create recording as draft if in draft mode
            let recording = Recording(
                id: UUID().uuidString,
                meetingId: isDraftMode ? nil : preparedMeeting?.id,
                projectId: isDraftMode ? nil : preparedMeeting?.projectId,
                fileName: fileURL.lastPathComponent,
                customName: nil,
                localFilePath: fileURL.path,
                fileSize: fileSize,
                duration: duration,
                contentHash: nil,
                uploadStatus: .pending,
                uploadProgress: 0,
                uploadId: nil,
                createdAt: Date(),
                actualStartAt: startAt,
                actualEndAt: Date()
            )

            print("🎤 [RecorderViewModel] Created recording with meetingId: \(String(describing: recording.meetingId)), projectId: \(String(describing: recording.projectId))")

            try container.recordingLocalStore.upsert(recording)
            await loadLocalRecordings()

            // Only upload if not in draft mode (has project binding)
            if !isDraftMode {
                print("🎤 [RecorderViewModel] Uploading recording (not draft mode)")
                try await upload(recording: recording)
            } else {
                print("🎤 [RecorderViewModel] Saving as draft (draft mode)")
                // Save the recording ID and show alert
                completedDraftRecordingId = recording.id
                status = .idle
                showSaveToProjectAlert = true
            }
        } catch {
            print("❌ [RecorderViewModel] Error in stopRecording: \(error)")
            errorMessage = error.localizedDescription
            status = .idle
        }

        recordingURL = nil
        recordingStartAt = nil
        resetWaveform()
    }

    func cancelRecording() {
        guard let container, let fileURL = recordingURL else {
            status = .idle
            return
        }

        print("🎤 [RecorderViewModel] cancelRecording called")

        // Stop recording service
        container.audioRecorderService.stopRecording()

        // Delete the recording file
        try? container.fileStorageService.removeFile(at: fileURL)

        // Reset state
        recordingURL = nil
        recordingStartAt = nil
        resetWaveform()
        status = .idle

        print("🎤 [RecorderViewModel] Recording cancelled and file deleted")
    }

    func retryUpload(recording: Recording) async {
        do {
            try await upload(recording: recording)
        } catch {
            errorMessage = error.localizedDescription
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

    func delete(recording: Recording) async {
        guard let container else { return }

        do {
            if playingRecordingId == recording.id {
                container.audioPlayerService.stop()
            }

            try container.recordingLocalStore.remove(recording.id)
            let fileURL = URL(fileURLWithPath: recording.localFilePath)
            try container.fileStorageService.removeFile(at: fileURL)
            await loadLocalRecordings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func projectSelectionDidChange() async {
        if preparedMeeting != nil { return }
        await loadLocalRecordings()
    }

    private func resetWaveform() {
        waveformSamples = Array(repeating: 0.1, count: waveformCapacity)
    }

    private func appendWaveform(level: Float) {
        let normalized = max(0.05, min(1, CGFloat(level)))
        var samples = waveformSamples
        samples.append(normalized)
        if samples.count > waveformCapacity {
            samples.removeFirst()
        }
        withAnimation(.easeOut(duration: 0.1)) {
            waveformSamples = samples
        }
    }

    private func upload(recording: Recording) async throws {
        guard let container else { throw APIError.networkUnavailable }

        // Skip upload for draft recordings (no project binding)
        guard let meetingId = recording.meetingId, !meetingId.isEmpty else {
            return
        }

        status = .uploading(progress: 0)

        let fileURL = URL(fileURLWithPath: recording.localFilePath)
        let actualStart = recording.actualStartAt ?? Date()
        let actualEnd = recording.actualEndAt ?? Date()
        do {
            let application = try await container.recordingUploadService.uploadRecording(
                meetingId: meetingId,
                fileURL: fileURL,
                actualStartAt: actualStart,
                actualEndAt: actualEnd,
                fileType: "COMPLETE_RECORDING_FILE",
                fromType: "GBASE",
                customName: recording.customName,
                progressHandler: { [weak self] progress in
                Task { @MainActor in
                    if progress >= 100 {
                        self?.status = .completed
                        // 短暂显示完成状态后回到空闲状态
                        Task {
                            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
                            await MainActor.run {
                                self?.status = .idle
                            }
                        }
                    } else {
                        self?.status = .uploading(progress: progress)
                    }
                    try? container.recordingLocalStore.update(id: recording.id,
                                                              status: progress >= 100 ? .completed : .uploading,
                                                              progress: progress)
                    await self?.loadLocalRecordings()
                }
            })

            try container.recordingLocalStore.update(id: recording.id, status: .completed, progress: 100)
            await loadLocalRecordings()
            Logger.debug("上传完成: \(application.uuid)")

            // 如果进度回调还没触发完成状态，确保状态已更新
            if case .uploading = status {
                status = .completed
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
                await MainActor.run {
                    status = .idle
                }
            }
        } catch {
            try? container.recordingLocalStore.update(id: recording.id, status: .failed, progress: 0)
            await loadLocalRecordings()
            status = .idle
            throw error
        }
    }

    private func loadLocalRecordings() async {
        guard let container else { return }
        do {
            localRecordings = try container.recordingLocalStore.fetch(projectId: selectedProjectId, status: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pruneRecordings(for validProjectIds: Set<String>) async {
        guard let container else { return }

        do {
            let recordings = try container.recordingLocalStore.fetch(projectId: nil, status: nil)
            for recording in recordings {
                // Skip draft recordings (they don't have projectId)
                guard let projectId = recording.projectId else { continue }

                // Only delete recordings with invalid projectId
                if !validProjectIds.contains(projectId) {
                    try container.recordingLocalStore.remove(recording.id)
                    let fileURL = URL(fileURLWithPath: recording.localFilePath)
                    try container.fileStorageService.removeFile(at: fileURL)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func durationOfFile(at url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        if #available(iOS 16.0, *) {
            let cmTime = try await asset.load(.duration)
            return Double(CMTimeGetSeconds(cmTime))
        } else {
            return Double(CMTimeGetSeconds(asset.duration))
        }
    }
    
    // Save draft recording to project
    func saveDraftToProject() async {
        guard let container, let recordingId = completedDraftRecordingId, let projectId = saveToProjectSelectedProjectId else {
            return
        }
        
        isBindingToProject = true
        defer { isBindingToProject = false }
        
        do {
            // Fetch the recording
            let recordings = try container.recordingLocalStore.fetch(projectId: nil, status: nil)
            guard let recording = recordings.first(where: { $0.id == recordingId }) else {
                errorMessage = LocalizedStringKey.draftDetailRecordingNotFound.localized
                return
            }
            
            // Create a meeting for this recording
            let meetingTitle = recording.customName ?? "\(LocalizedStringKey.quickRecorderDefaultName.localized) - \(formatDate(recording.createdAt))"
            let meeting = try await container.createMeetingUseCase.execute(
                projectId: projectId,
                title: meetingTitle,
                meetingTime: recording.createdAt,
                location: nil,
                description: LocalizedStringKey.draftDetailBindingDescription.localized
            )
            
            // Bind the draft to the project and meeting
            try container.bindDraftToProjectUseCase.execute(
                recordingId: recordingId,
                projectId: projectId,
                meetingId: meeting.id,
                customName: recording.customName
            )
            
            // Fetch the updated recording
            let updatedRecordings = try container.recordingLocalStore.fetch(projectId: nil, status: nil)
            guard let updatedRecording = updatedRecordings.first(where: { $0.id == recordingId }) else {
                errorMessage = LocalizedStringKey.draftDetailRecordingNotFound.localized
                return
            }
            
            // Upload the recording
            try await upload(recording: updatedRecording)
            
            // Clear the alert state
            showSaveToProjectAlert = false
            completedDraftRecordingId = nil
            saveToProjectSelectedProjectId = nil
            await loadLocalRecordings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func dismissSaveToProjectAlert() {
        showSaveToProjectAlert = false
        completedDraftRecordingId = nil
        saveToProjectSelectedProjectId = nil
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

extension RecorderViewModel: AudioRecorderServiceDelegate {
    nonisolated public func recorderDidUpdate(duration: TimeInterval, level: Float) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.status = .recording(duration: duration)
            self.appendWaveform(level: level)
        }
    }

    nonisolated public func recorderDidFinish(successfully flag: Bool, fileURL: URL?) {
        // 录音完成后交给 stopRecording 逻辑
    }

    nonisolated public func recorderDidFail(_ error: Error) {
        Task { @MainActor [weak self] in
            self?.errorMessage = error.localizedDescription
            self?.status = .idle
        }
    }
}

extension RecorderViewModel: AudioPlayerServiceDelegate {
    public func playerDidStart(url: URL) {}

    public func playerDidFinish() {
        playingRecordingId = nil
    }

    public func playerDidFail(_ error: Error) {
        playingRecordingId = nil
        errorMessage = error.localizedDescription
    }
}


import Foundation
import Combine
import SwiftUI
import AVFoundation
import CoreMedia

@MainActor
final class RecorderViewModel: NSObject, ObservableObject {
    enum Status: Equatable {
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

    struct ProjectOption: Identifiable, Equatable {
        let id: String
        let title: String
    }

    private var container: DIContainer?
    private var recordingURL: URL?
    private var recordingStartAt: Date?
    private let waveformCapacity = 24

    override init() {
        waveformSamples = Array(repeating: 0.1, count: waveformCapacity)
        super.init()
    }

    func configure(container: DIContainer, shouldLoadProjects: Bool = true) {
        self.container = container
        container.audioRecorderService.delegate = self
        container.audioPlayerService.delegate = self
        resetWaveform()
        if shouldLoadProjects {
            Task { await loadProjects() }
            Task { await loadLocalRecordings() }
        }
    }

    func prepare(for project: Project, meeting: Meeting) {
        selectedProjectId = project.id
        selectedProjectTitle = project.title
        meetingTitle = meeting.title
        preparedMeeting = meeting

        if !projectOptions.contains(where: { $0.id == project.id }) {
            projectOptions.insert(ProjectOption(id: project.id, title: project.title), at: 0)
        }

        Task { await loadLocalRecordings() }
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

        guard let meeting = preparedMeeting else {
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
            let fileURL = try container.fileStorageService.makeRecordingURL(timestamp: now, meetingId: meeting.id)
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
        guard let container, let meeting = preparedMeeting, let fileURL = recordingURL, let startAt = recordingStartAt else {
            status = .idle
            return
        }

        container.audioRecorderService.stopRecording()
        status = .processing

        do {
            let fileSize = try container.fileStorageService.fileSize(at: fileURL)
            let duration = try await durationOfFile(at: fileURL)
            let recording = Recording(id: UUID().uuidString,
                                      meetingId: meeting.id,
                                      projectId: meeting.projectId,
                                      fileName: fileURL.lastPathComponent,
                                      localFilePath: fileURL.path,
                                      fileSize: fileSize,
                                      duration: duration,
                                      contentHash: nil,
                                      uploadStatus: .pending,
                                      uploadProgress: 0,
                                      uploadId: nil,
                                      createdAt: Date(),
                                      actualStartAt: startAt,
                                      actualEndAt: Date())

            try container.recordingLocalStore.upsert(recording)
            await loadLocalRecordings()
            try await upload(recording: recording)
        } catch {
            errorMessage = error.localizedDescription
            status = .idle
        }

        recordingURL = nil
        recordingStartAt = nil
        resetWaveform()
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
        status = .uploading(progress: 0)

        let fileURL = URL(fileURLWithPath: recording.localFilePath)
        let actualStart = recording.actualStartAt ?? Date()
        let actualEnd = recording.actualEndAt ?? Date()
        do {
            let application = try await container.recordingUploadService.uploadRecording(meetingId: recording.meetingId,
                                                                                        fileURL: fileURL,
                                                                                        actualStartAt: actualStart,
                                                                                        actualEndAt: actualEnd,
                                                                                        fileType: "COMPLETE_RECORDING_FILE",
                                                                                        fromType: "GBASE",
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
            for recording in recordings where !validProjectIds.contains(recording.projectId) {
                try container.recordingLocalStore.remove(recording.id)
                let fileURL = URL(fileURLWithPath: recording.localFilePath)
                try container.fileStorageService.removeFile(at: fileURL)
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
}

extension RecorderViewModel: AudioRecorderServiceDelegate {
    nonisolated func recorderDidUpdate(duration: TimeInterval, level: Float) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.status = .recording(duration: duration)
            self.appendWaveform(level: level)
        }
    }

    nonisolated func recorderDidFinish(successfully flag: Bool, fileURL: URL?) {
        // 录音完成后交给 stopRecording 逻辑
    }

    nonisolated func recorderDidFail(_ error: Error) {
        Task { @MainActor [weak self] in
            self?.errorMessage = error.localizedDescription
            self?.status = .idle
        }
    }
}

extension RecorderViewModel: AudioPlayerServiceDelegate {
    func playerDidStart(url: URL) {}

    func playerDidFinish() {
        playingRecordingId = nil
    }

    func playerDidFail(_ error: Error) {
        playingRecordingId = nil
        errorMessage = error.localizedDescription
    }
}


import Foundation
import Combine

@MainActor
final class MeetingDetailViewModel: ObservableObject {
    @Published var detail: MeetingDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var playingRecordingId: String?

    private let meetingId: String
    private var container: DIContainer?

    init(meetingId: String) {
        self.meetingId = meetingId
    }

    func configure(container: DIContainer) {
        self.container = container
        container.audioPlayerService.delegate = self
    }

    func load() async {
        guard let container else {
            errorMessage = "依赖未注入"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await container.fetchMeetingDetailUseCase.execute(meetingId: meetingId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePlayback(recording: Recording) {
        guard let container else { return }

        // Use remote URL directly (mapped to localFilePath by RecordingMapper)
        // or local file path if available
        guard let url = URL(string: recording.localFilePath) else {
            errorMessage = "无效的音频路径"
            return
        }

        do {
            if playingRecordingId == recording.id {
                container.audioPlayerService.stop()
            } else {
                try container.audioPlayerService.play(url: url)
                playingRecordingId = recording.id
            }
        } catch {
            errorMessage = error.localizedDescription
            playingRecordingId = nil
        }
    }
    
    func isPlaying(recording: Recording) -> Bool {
        return playingRecordingId == recording.id
    }
}

extension MeetingDetailViewModel: AudioPlayerServiceDelegate {
    func playerDidStart(url: URL) {}

    func playerDidFinish() {
        playingRecordingId = nil
    }

    func playerDidFail(_ error: Error) {
        playingRecordingId = nil
        errorMessage = error.localizedDescription
    }
}


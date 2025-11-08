import Foundation
import Combine
import SwiftUI

@MainActor
final class DraftsViewModel: ObservableObject {
    @Published var drafts: [Recording] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var playingRecordingId: String?

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
            drafts = try container.fetchDraftsUseCase.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteDraft(_ recording: Recording) async {
        guard let container else { return }

        do {
            if playingRecordingId == recording.id {
                container.audioPlayerService.stop()
            }

            try container.deleteDraftUseCase.execute(recordingId: recording.id)
            await loadDrafts()
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

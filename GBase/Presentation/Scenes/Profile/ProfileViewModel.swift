import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var isProcessing: Bool = false
    @Published var alertMessage: String?

    private var container: DIContainer?

    func configure(container: DIContainer) {
        self.container = container
    }

    func clearCache() async {
        guard let container else {
            alertMessage = LocalizedStringKey.profileDependencyNotInjected.localized
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let recordings = try container.recordingLocalStore.fetch(projectId: nil, status: nil)
            for recording in recordings {
                try container.recordingLocalStore.remove(recording.id)
                let fileURL = URL(fileURLWithPath: recording.localFilePath)
                try container.fileStorageService.removeFile(at: fileURL)
            }

            container.audioPlayerService.stop()
            container.audioRecorderService.cancelRecording(delete: false)
            alertMessage = LocalizedStringKey.profileCacheCleared.localized
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func logout() async {
        guard let container else {
            alertMessage = LocalizedStringKey.profileDependencyNotInjected.localized
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await container.tokenStore.removeSession()
            container.audioPlayerService.stop()
            container.audioRecorderService.cancelRecording(delete: false)
            container.appState.markUnauthenticated()
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}


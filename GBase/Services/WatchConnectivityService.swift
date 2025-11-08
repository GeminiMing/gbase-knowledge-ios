import Foundation
import WatchConnectivity

/// Service to handle communication between iPhone and Apple Watch
public class WatchConnectivityService: NSObject, ObservableObject {
    public static let shared = WatchConnectivityService()

    @Published public var isWatchConnected = false
    @Published public var lastReceivedRecording: Recording?

    private let recordingLocalStore: RecordingLocalStore
    private let fileStorageService: FileStorageService
    private var session: WCSession?

    private override init() {
        self.recordingLocalStore = RealmRecordingLocalStore()
        self.fileStorageService = FileStorageService()
        super.init()
        setupSession()
    }

    public init(recordingLocalStore: RecordingLocalStore, fileStorageService: FileStorageService) {
        self.recordingLocalStore = recordingLocalStore
        self.fileStorageService = fileStorageService
        super.init()
        setupSession()
    }

    private func setupSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity is not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Send Messages to Watch

    public func sendDraftConfirmation(recordingId: String) {
        guard let session = session, session.isReachable else {
            print("Watch is not reachable")
            return
        }

        let message: [String: Any] = [
            "type": "draftSaved",
            "recordingId": recordingId,
            "timestamp": Date().timeIntervalSince1970
        ]

        session.sendMessage(message, replyHandler: { response in
            print("Watch acknowledged draft save: \\(response)")
        }, errorHandler: { error in
            print("Failed to send draft confirmation to watch: \\(error)")
        })
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = (activationState == .activated)
        }

        if let error = error {
            print("WCSession activation failed: \\(error)")
        } else {
            print("WCSession activated successfully with state: \\(activationState.rawValue)")
        }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated, reactivating...")
        session.activate()
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = session.isReachable
            print("Watch reachability changed: \\(session.isReachable)")
        }
    }

    // MARK: - Receive Messages

    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message from Watch: \\(message)")
        handleReceivedMessage(message)
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Received message from Watch with reply handler: \\(message)")
        handleReceivedMessage(message)
        replyHandler(["status": "received", "timestamp": Date().timeIntervalSince1970])
    }

    // MARK: - File Transfer

    public func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("Received file from Watch: \\(file.fileURL.lastPathComponent)")

        Task {
            await handleReceivedFile(file)
        }
    }

    // MARK: - Handle Received Data

    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "recording":
            print("Recording metadata received from Watch")
            // Metadata is handled when file arrives
            break
        default:
            print("Unknown message type: \\(type)")
        }
    }

    private func handleReceivedFile(_ file: WCSessionFile) async {
        let metadata = file.metadata ?? [:]

        guard let fileName = metadata["fileName"] as? String,
              let duration = metadata["duration"] as? TimeInterval,
              let timestamp = metadata["timestamp"] as? TimeInterval,
              let fileSize = metadata["fileSize"] as? Int else {
            print("Invalid file metadata")
            return
        }

        do {
            // Move file to app's documents directory
            let destinationURL = try fileStorageService.saveRecordingFile(from: file.fileURL, fileName: fileName)

            // Create Recording entity as draft
            let recording = Recording(
                id: UUID().uuidString,
                meetingId: nil,  // Draft - no meeting
                projectId: nil,  // Draft - no project
                fileName: fileName,
                customName: "Watch Recording \\(formatDate(Date(timeIntervalSince1970: timestamp)))",
                localFilePath: destinationURL.path,
                fileSize: Int64(fileSize),
                duration: duration,
                uploadStatus: .pending,
                uploadProgress: 0,
                recordedAt: Date(timeIntervalSince1970: timestamp),
                uploadedAt: nil,
                actualStartAt: Date(timeIntervalSince1970: timestamp),
                actualEndAt: Date(timeIntervalSince1970: timestamp + duration)
            )

            // Save to local store
            try recordingLocalStore.upsert(recording)

            // Update published property
            await MainActor.run {
                self.lastReceivedRecording = recording
            }

            // Send confirmation back to Watch
            sendDraftConfirmation(recordingId: recording.id)

            print("✅ Recording saved as draft: \\(recording.id)")

        } catch {
            print("❌ Failed to save recording from Watch: \\(error)")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

import Foundation
import WatchConnectivity
import Combine

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
        print("📱 [iPhone] Setting up WCSession...")

        guard WCSession.isSupported() else {
            print("❌ [iPhone] WatchConnectivity is not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self

        print("📱 [iPhone] Activating WCSession...")
        session?.activate()
    }

    // MARK: - Send Messages to Watch

    public func sendDraftConfirmation(recordingId: String) {
        guard let session = session, session.isReachable else {
            print("Watch is not reachable or session is not available")
            return
        }

        let message: [String: Any] = [
            "type": "draftSaved",
            "recordingId": recordingId,
            "timestamp": Date().timeIntervalSince1970
        ]

        session.sendMessage(message, replyHandler: { response in
            print("Watch acknowledged draft save: \(response)")
        }, errorHandler: { error in
            print("Failed to send draft confirmation to watch: \(error)")
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
            // 忽略 "counterpart app not installed" 错误，这是正常的（如果没有配对 Watch 或没有安装 Watch 应用）
            let errorDescription = error.localizedDescription
            if errorDescription.contains("counterpart app not installed") {
                // 这是正常情况，不需要记录为错误
                return
            }
            print("❌ [iPhone] WCSession activation failed: \(errorDescription)")
            print("❌ [iPhone] Error details: \(error)")
            print("📱 [iPhone] Activation state: \(activationState.rawValue)")
            print("📱 [iPhone] Session info - isPaired: \(session.isPaired), isWatchAppInstalled: \(session.isWatchAppInstalled), isReachable: \(session.isReachable)")
        } else {
            print("✅ [iPhone] WCSession activated successfully with state: \(activationState.rawValue)")
            print("📱 [iPhone] Is paired: \(session.isPaired)")
            print("📱 [iPhone] Is watch app installed: \(session.isWatchAppInstalled)")
            print("📱 [iPhone] Is reachable: \(session.isReachable)")
        }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ [iPhone] WCSession became inactive")
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ [iPhone] WCSession deactivated, reactivating...")
        session.activate()
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = session.isReachable
            print("📱 [iPhone] Watch reachability changed: \(session.isReachable)")
        }
    }

    // MARK: - Receive Messages

    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("📥 [iPhone] Received message from Watch: \(message)")
        handleReceivedMessage(message)
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("📥 [iPhone] Received message from Watch with reply handler: \(message)")
        handleReceivedMessage(message)
        replyHandler(["status": "received", "timestamp": Date().timeIntervalSince1970])
    }

    // MARK: - File Transfer

    public func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("📥 [iPhone] Received file from Watch: \(file.fileURL.lastPathComponent)")
        
        // CRITICAL: The system removes the file when this method returns.
        // We MUST move/copy the file synchronously before returning.
        // Do NOT use Task { } for the file operation.
        
        let metadata = file.metadata ?? [:]
        print("📥 [iPhone] File metadata: \(metadata)")
        
        // Check duration immediately if possible
        let duration = (metadata["duration"] as? TimeInterval) ?? 0
        if duration < 15.0 {
            print("⚠️ [iPhone] Recording duration too short (\(duration) seconds), ignoring file")
            return
        }

        // Extract filename
        let fileName = (metadata["fileName"] as? String) ?? file.fileURL.lastPathComponent
        
        do {
            // Synchronously save the file
            let savedURL = try fileStorageService.saveRecordingFile(from: file.fileURL, fileName: fileName)
            print("✅ [iPhone] File synchronously saved to: \(savedURL.path)")
            
            // Now process the saved file asynchronously
            Task {
                await processSavedFile(url: savedURL, metadata: metadata)
            }
        } catch {
            print("❌ [iPhone] Failed to save file synchronously: \(error)")
        }
    }
    
    // MARK: - Handle Received Data

    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { 
            print("⚠️ [iPhone] Received message without type field: \(message)")
            return 
        }

        switch type {
        case "recording":
            print("Recording metadata received from Watch")
            // Metadata is handled when file arrives
            break
        default:
            print("Unknown message type: \(type)")
        }
    }

    private func processSavedFile(url: URL, metadata: [String: Any]) async {
        print("📥 [iPhone] Processing saved file: \(url.lastPathComponent)")
        
        // Check if file exists (it should, we just saved it)
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ [iPhone] Saved file missing at path: \(url.path)")
            return
        }

        let duration = (metadata["duration"] as? TimeInterval) ?? 0
        let timestamp = (metadata["timestamp"] as? TimeInterval) ?? Date().timeIntervalSince1970

        // Get file size
        var fileSize: Int64 = 0
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = (attributes[.size] as? Int64) ?? 0
        } catch {
            print("⚠️ [iPhone] Could not get file size: \(error)")
        }
        
        if let metadataSize = metadata["fileSize"] as? Int, fileSize == 0 {
             fileSize = Int64(metadataSize)
        }

        print("📥 [iPhone] Creating recording entry - Duration: \(duration), Size: \(fileSize)")

        do {
            // Create Recording entity as draft
            let watchRecordingName = NSLocalizedString(LocalizedStringKey.watchRecordingDefaultName, comment: "")
            let recording = Recording(
                id: UUID().uuidString,
                meetingId: nil,  // Draft - no meeting
                projectId: nil,  // Draft - no project
                fileName: url.lastPathComponent,
                customName: "\(watchRecordingName) \(formatDate(Date(timeIntervalSince1970: timestamp)))",
                localFilePath: url.path,
                fileSize: fileSize,
                duration: duration,
                contentHash: nil,
                uploadStatus: .pending,
                uploadProgress: 0,
                uploadId: nil,
                createdAt: Date(timeIntervalSince1970: timestamp),
                actualStartAt: Date(timeIntervalSince1970: timestamp),
                actualEndAt: Date(timeIntervalSince1970: timestamp + duration)
            )

            print("📥 [iPhone] Saving recording to database: \(recording.id)")

            // Save to local store
            try recordingLocalStore.upsert(recording)
            print("✅ [iPhone] Recording saved to database")

            // Update published property and send notification to refresh UI
            await MainActor.run {
                self.lastReceivedRecording = recording
                // Notify DraftsView to refresh
                print("📢 [iPhone] Posting RefreshRecordings notification")
                NotificationCenter.default.post(name: NSNotification.Name("RefreshRecordings"), object: nil)
            }

            // Send confirmation back to Watch
            sendDraftConfirmation(recordingId: recording.id)
            
        } catch {
            print("❌ Failed to process saved recording: \(error)")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

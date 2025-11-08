import SwiftUI
import AVFoundation
import WatchConnectivity

@MainActor
class RecorderViewModel: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var duration: TimeInterval = 0
    @Published var permissionGranted = false

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingURL: URL?
    private var session: WCSession?

    override init() {
        super.init()
        setupWatchConnectivity()
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Watch Connectivity Setup
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Microphone Permission
    func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
                if granted {
                    self?.setupAudioSession()
                }
            }
        }
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \\(error)")
        }
    }

    // MARK: - Recording
    func startRecording() async {
        guard permissionGranted else {
            requestMicrophonePermission()
            return
        }

        // Create recording file URL
        let fileName = "recording_\\(Date().timeIntervalSince1970).m4a"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent(fileName)

        guard let url = recordingURL else { return }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()

            isRecording = true
            duration = 0

            // Start timer
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.duration += 1
                }
            }
        } catch {
            print("Failed to start recording: \\(error)")
        }
    }

    func stopRecording() async {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false

        // Send recording to iPhone
        if let url = recordingURL {
            await transferRecordingToiPhone(fileURL: url, duration: duration)
        }

        // Reset
        duration = 0
        recordingURL = nil
    }

    // MARK: - Transfer to iPhone
    private func transferRecordingToiPhone(fileURL: URL, duration: TimeInterval) async {
        guard let session = session, session.isReachable else {
            print("iPhone is not reachable")
            // Store locally for later sync
            storeRecordingLocally(fileURL: fileURL, duration: duration)
            return
        }

        do {
            let audioData = try Data(contentsOf: fileURL)
            let metadata: [String: Any] = [
                "type": "recording",
                "fileName": fileURL.lastPathComponent,
                "duration": duration,
                "timestamp": Date().timeIntervalSince1970,
                "fileSize": audioData.count
            ]

            // Send file via WatchConnectivity
            session.sendMessage(metadata, replyHandler: { response in
                print("Successfully sent metadata to iPhone: \\(response)")
            }, errorHandler: { error in
                print("Failed to send metadata: \\(error)")
            })

            // Transfer file
            session.transferFile(fileURL, metadata: metadata)
            print("Recording transferred to iPhone")

        } catch {
            print("Failed to transfer recording: \\(error)")
            storeRecordingLocally(fileURL: fileURL, duration: duration)
        }
    }

    private func storeRecordingLocally(fileURL: URL, duration: TimeInterval) {
        // Store recording info in UserDefaults for later sync
        var pendingRecordings = UserDefaults.standard.array(forKey: "pendingRecordings") as? [[String: Any]] ?? []
        let recording: [String: Any] = [
            "fileName": fileURL.lastPathComponent,
            "filePath": fileURL.path,
            "duration": duration,
            "timestamp": Date().timeIntervalSince1970
        ]
        pendingRecordings.append(recording)
        UserDefaults.standard.set(pendingRecordings, forKey: "pendingRecordings")
        print("Recording stored locally for later sync")
    }
}

// MARK: - WCSessionDelegate
extension RecorderViewModel: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \\(error)")
        } else {
            print("WCSession activated with state: \\(activationState.rawValue)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message from iPhone: \\(message)")
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Received message from iPhone with reply handler: \\(message)")
        replyHandler(["status": "received"])
    }
}

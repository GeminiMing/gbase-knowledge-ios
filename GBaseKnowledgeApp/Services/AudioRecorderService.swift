import Foundation
import AVFoundation
import AVFAudio
import QuartzCore

public protocol AudioRecorderServiceDelegate: AnyObject {
    func recorderDidUpdate(duration: TimeInterval, level: Float)
    func recorderDidFinish(successfully flag: Bool, fileURL: URL?)
    func recorderDidFail(_ error: Error)
}

public final class AudioRecorderService: NSObject {
    public weak var delegate: AudioRecorderServiceDelegate?

    private var recorder: AVAudioRecorder?
    private var displayLink: CADisplayLink?
    private var startDate: Date?
    private let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 2,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsNonInterleaved: false
    ]

    public override init() {
        super.init()
    }

    public func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    public func startRecording(to url: URL) throws {
        try configureSession()

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.delegate = self
        recorder?.isMeteringEnabled = true

        if recorder?.record() == true {
            startDate = Date()
            activateDisplayLink()
        } else {
            throw RecorderError.failedToStart
        }
    }

    public func stopRecording() {
        recorder?.stop()
        recorder = nil
        deactivateDisplayLink()
    }

    public func cancelRecording(delete: Bool = true) {
        guard let recorder else { return }
        recorder.stop()
        if delete {
            recorder.deleteRecording()
        }
        self.recorder = nil
        deactivateDisplayLink()
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        var options: AVAudioSession.CategoryOptions = [.duckOthers]
        if #available(iOS 10.0, *) {
            options.insert(.allowBluetoothA2DP)
            options.insert(.allowBluetoothHFP)
        } else {
            options.insert(.allowBluetooth)
        }

        try session.setCategory(.playAndRecord, mode: .default, options: options)
        try session.setActive(true)
    }

    private func activateDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateDuration))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func deactivateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateDuration() {
        guard let startDate else { return }
        let duration = Date().timeIntervalSince(startDate)
        var level: Float = 0
        if let recorder {
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            let linearLevel = pow(10, power / 20)
            level = max(0, min(1, linearLevel))
        }
        delegate?.recorderDidUpdate(duration: duration, level: level)
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        delegate?.recorderDidFinish(successfully: flag, fileURL: flag ? recorder.url : nil)
        deactivateDisplayLink()
    }

    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error {
            delegate?.recorderDidFail(error)
        } else {
            delegate?.recorderDidFail(RecorderError.unknown)
        }
        deactivateDisplayLink()
    }
}

public enum RecorderError: Error {
    case failedToStart
    case unknown
}


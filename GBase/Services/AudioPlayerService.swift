import Foundation
import AVFoundation

@MainActor
public protocol AudioPlayerServiceDelegate: AnyObject {
    func playerDidStart(url: URL)
    func playerDidFinish()
    func playerDidFail(_ error: Error)
}

@MainActor
public final class AudioPlayerService: NSObject {
    public weak var delegate: AudioPlayerServiceDelegate?

    private var player: AVAudioPlayer?
    private var currentURL: URL?

    public override init() {
        super.init()
    }

    public func play(url: URL) throws {
        if currentURL == url, player?.isPlaying == true {
            stop()
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioPlayerError.fileNotFound
        }

        stop()
        try configureSession()

        // Detect file type from extension
        let fileExtension = url.pathExtension.lowercased()
        let fileTypeHint: String? = {
            switch fileExtension {
            case "wav":
                return AVFileType.wav.rawValue
            case "m4a", "aac":
                return AVFileType.m4a.rawValue  // M4A handles AAC audio
            case "mp3":
                return AVFileType.mp3.rawValue
            default:
                return nil // Let AVAudioPlayer auto-detect
            }
        }()

        let audioPlayer = try AVAudioPlayer(contentsOf: url, fileTypeHint: fileTypeHint)
        audioPlayer.delegate = self
        audioPlayer.prepareToPlay()

        guard audioPlayer.play() else {
            throw AudioPlayerError.failedToPlay
        }

        player = audioPlayer
        currentURL = url
        delegate?.playerDidStart(url: url)
    }

    public func stop() {
        guard let player else { return }
        player.stop()
        self.player = nil
        currentURL = nil
        deactivateSession()
        delegate?.playerDidFinish()
    }

    public func pause() {
        player?.pause()
    }

    public var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    public var currentTime: TimeInterval {
        player?.currentTime ?? 0
    }

    public var duration: TimeInterval {
        player?.duration ?? 0
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension AudioPlayerService: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        currentURL = nil
        deactivateSession()
        delegate?.playerDidFinish()
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        self.player = nil
        currentURL = nil
        deactivateSession()
        delegate?.playerDidFail(error ?? AudioPlayerError.unknown)
    }
}

public enum AudioPlayerError: Error {
    case failedToPlay
    case unknown
    case fileNotFound
}

extension AudioPlayerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToPlay:
            return "无法播放该音频文件"
        case .unknown:
            return "未知的音频播放错误"
        case .fileNotFound:
            return "找不到本地录音文件"
        }
    }
}


import Foundation
import AVFoundation
import CoreMedia

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
    private var avPlayer: AVPlayer?
    private var playerItemObserver: Any?
    private var currentURL: URL?
    private var isUsingAVPlayer = false

    public override init() {
        super.init()
    }

    public func play(url: URL) throws {
        // Stop current playback if same URL is playing
        if currentURL == url {
            if isUsingAVPlayer {
                if avPlayer?.rate != 0 {
                    stop()
                    return
                }
            } else {
                if player?.isPlaying == true {
                    stop()
                    return
                }
            }
        }

        if url.isFileURL {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw AudioPlayerError.fileNotFound
            }
        }
        
        stop()
        try configureSession()
        
        // If it's a remote URL, directly use AVPlayer
        if !url.isFileURL {
            playRemote(url: url)
            return
        }

        // Detect file type from extension
        let fileExtension = url.pathExtension.lowercased()
        let fileTypeHint: String? = {
            switch fileExtension {
            case "wav":
                return AVFileType.wav.rawValue
            case "m4a", "aac":
                return AVFileType.m4a.rawValue
            case "mp3":
                return AVFileType.mp3.rawValue
            default:
                return nil
            }
        }()

        do {
            // Try AVAudioPlayer first
            let audioPlayer = try AVAudioPlayer(contentsOf: url, fileTypeHint: fileTypeHint)
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()

            guard audioPlayer.play() else {
                throw AudioPlayerError.failedToPlay
            }

            player = audioPlayer
            isUsingAVPlayer = false
            currentURL = url
            delegate?.playerDidStart(url: url)
            print("✅ [AudioPlayer] Using AVAudioPlayer")
        } catch {
            print("⚠️ [AudioPlayer] AVAudioPlayer failed: \(error). Falling back to AVPlayer.")
            
            // Fallback to AVPlayer
            let playerItem = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: playerItem)
            
            // Observe playback finish
            NotificationCenter.default.addObserver(self,
                                                 selector: #selector(playerDidFinishPlaying),
                                                 name: .AVPlayerItemDidPlayToEndTime,
                                                 object: playerItem)
            
            // Observe playback failure
            NotificationCenter.default.addObserver(self,
                                                 selector: #selector(playerFailedToPlay),
                                                 name: .AVPlayerItemFailedToPlayToEndTime,
                                                 object: playerItem)
            
            player.play()
            
            self.avPlayer = player
            self.isUsingAVPlayer = true
            self.currentURL = url
            delegate?.playerDidStart(url: url)
            print("✅ [AudioPlayer] Using AVPlayer fallback")
        }
    }

    public func stop() {
        if isUsingAVPlayer {
            avPlayer?.pause()
            avPlayer?.replaceCurrentItem(with: nil)
            avPlayer = nil
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
        } else {
            player?.stop()
            player = nil
        }
        
        currentURL = nil
        deactivateSession()
        delegate?.playerDidFinish()
    }

    public func pause() {
        if isUsingAVPlayer {
            avPlayer?.pause()
        } else {
            player?.pause()
        }
    }

    public var isPlaying: Bool {
        if isUsingAVPlayer {
            return avPlayer?.rate != 0
        } else {
            return player?.isPlaying ?? false
        }
    }

    public var currentTime: TimeInterval {
        if isUsingAVPlayer {
            guard let currentTime = avPlayer?.currentTime() else { return 0 }
            return CMTimeGetSeconds(currentTime)
        } else {
            return player?.currentTime ?? 0
        }
    }

    public var duration: TimeInterval {
        if isUsingAVPlayer {
            guard let duration = avPlayer?.currentItem?.duration else { return 0 }
            return CMTimeGetSeconds(duration)
        } else {
            return player?.duration ?? 0
        }
    }
    
    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        Task { @MainActor in
            stop()
        }
    }
    
    @objc private func playerFailedToPlay(_ notification: Notification) {
        Task { @MainActor in
            let error = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error) ?? AudioPlayerError.failedToPlay
            stop()
            delegate?.playerDidFail(error)
        }
    }

    private func playRemote(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        
        // Observe playback finish
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(playerDidFinishPlaying),
                                             name: .AVPlayerItemDidPlayToEndTime,
                                             object: playerItem)
        
        // Observe playback failure
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(playerFailedToPlay),
                                             name: .AVPlayerItemFailedToPlayToEndTime,
                                             object: playerItem)
        
        player.play()
        
        self.avPlayer = player
        self.isUsingAVPlayer = true
        self.currentURL = url
        delegate?.playerDidStart(url: url)
        print("✅ [AudioPlayer] Playing remote URL with AVPlayer")
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


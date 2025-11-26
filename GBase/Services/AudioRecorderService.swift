import Foundation
import AVFoundation
import AVFAudio
import QuartzCore
import UIKit

public protocol AudioRecorderServiceDelegate: AnyObject {
    func recorderDidUpdate(duration: TimeInterval, level: Float)
    func recorderDidFinish(successfully flag: Bool, fileURL: URL?)
    func recorderDidFail(_ error: Error)
}

public final class AudioRecorderService: NSObject {
    public weak var delegate: AudioRecorderServiceDelegate?

    private var recorder: AVAudioRecorder?
    private var displayLink: CADisplayLink?
    private var timer: Timer?
    private var startDate: Date?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var checkCount = 0
    private let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 2,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    public override init() {
        super.init()
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func requestPermission() async -> Bool {
        // 先检查当前权限状态
        let currentStatus: AVAudioSession.RecordPermission
        if #available(iOS 17.0, *) {
            currentStatus = AVAudioApplication.shared.recordPermission
        } else {
            currentStatus = AVAudioSession.sharedInstance().recordPermission
        }

        print("🎤 [AudioRecorderService] Current permission status: \(currentStatus.rawValue)")

        // 如果已经授权，直接返回
        if currentStatus == .granted {
            print("✅ [AudioRecorderService] Permission already granted")
            return true
        }

        // 如果已经拒绝，直接返回
        if currentStatus == .denied {
            print("❌ [AudioRecorderService] Permission already denied")
            return false
        }

        // 状态是 .undetermined，请求权限
        print("🎤 [AudioRecorderService] Requesting permission...")
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    print("🎤 [AudioRecorderService] Permission result: \(granted)")
                    continuation.resume(returning: granted)
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    print("🎤 [AudioRecorderService] Permission result: \(granted)")
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
            beginBackgroundTask()
            activateDisplayLink()
            activateTimer()

            // 启动 Live Activity（iOS 16.1+）
            // 注意：需要先在 Xcode 中添加 RecordingLiveActivity.swift 文件
            // if #available(iOS 16.1, *) {
            //     RecordingLiveActivityService.shared.start(title: "语音录音")
            // }
        } else {
            throw RecorderError.failedToStart
        }
    }

    public func stopRecording() {
        // 获取最终时长
        let finalDuration = recorder?.currentTime ?? 0

        recorder?.stop()
        recorder = nil
        endBackgroundTask()
        deactivateDisplayLink()
        deactivateTimer()

        // 结束 Live Activity（iOS 16.1+）
        // if #available(iOS 16.1, *) {
        //     RecordingLiveActivityService.shared.finish(duration: finalDuration)
        // }

        // 注意：不在这里停用音频会话，因为可能还有其他音频操作
        // 让系统自动管理会话生命周期
    }

    public func cancelRecording(delete: Bool = true) {
        guard let recorder else { return }
        recorder.stop()
        if delete {
            recorder.deleteRecording()
        }
        self.recorder = nil
        endBackgroundTask()
        deactivateDisplayLink()
        deactivateTimer()

        // 停止 Live Activity（iOS 16.1+）
        // if #available(iOS 16.1, *) {
        //     RecordingLiveActivityService.shared.stop()
        // }
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()

        // 使用 .playAndRecord 是最可靠的方式
        // .playAndRecord + UIBackgroundModes: audio 可以实现后台录音
        let options: AVAudioSession.CategoryOptions = [
            .defaultToSpeaker,      // 默认使用扬声器
            .allowBluetooth,        // 允许蓝牙设备
            .allowBluetoothA2DP     // 允许高质量蓝牙音频
        ]

        // 配置音频会话 - 使用 .default mode 最稳定
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: options)
            print("✅ 音频会话配置成功 - .playAndRecord category")
        } catch let error as NSError {
            print("❌ 音频会话配置失败: \(error.localizedDescription)")
            print("❌ 错误码: \(error.code), 域: \(error.domain)")

            // 检查是否是因为音频会话被占用
            if error.code == AVAudioSession.ErrorCode.isBusy.rawValue {
                throw RecorderError.sessionBusy
            }
            throw error
        }

        // 激活会话
        do {
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
            print("✅ 音频会话激活成功 - 支持后台录音")
        } catch let error as NSError {
            print("⚠️ 会话激活失败: \(error.localizedDescription)")
            print("⚠️ 错误码: \(error.code), 域: \(error.domain)")

            // 检查是否是因为音频会话被占用
            if error.code == AVAudioSession.ErrorCode.isBusy.rawValue {
                throw RecorderError.sessionBusy
            }

            // 尝试先停用再激活
            do {
                try session.setActive(false, options: [])
                try session.setActive(true, options: [.notifyOthersOnDeactivation])
                print("✅ 音频会话强制激活成功")
            } catch let retryError as NSError {
                print("❌ 强制激活失败: \(retryError.localizedDescription)")

                if retryError.code == AVAudioSession.ErrorCode.isBusy.rawValue {
                    throw RecorderError.sessionBusy
                }

                // 最后尝试无选项激活
                try session.setActive(true)
                print("⚠️ 音频会话激活（无选项）")
            }
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // 监听音频会话中断
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        // 监听音频会话路由变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    @objc private func applicationDidEnterBackground() {
        guard let recorder = recorder else { return }

        print("📱 应用进入后台，检查录音状态...")

        // 验证录音器仍在运行
        if !recorder.isRecording {
            print("⚠️ 录音器已停止，尝试重新启动...")
            // 如果录音器停止了，尝试重新启动
            do {
                try configureSession()
                if recorder.record() {
                    print("✅ 录音器重新启动成功")
                } else {
                    print("❌ 录音器重新启动失败")
                    delegate?.recorderDidFail(RecorderError.failedToStart)
                }
            } catch {
                print("⚠️ 后台录音会话配置失败: \(error)")
                // 不在这里报告错误，因为可能是临时性的
            }
        } else {
            print("✅ 录音器仍在运行，当前时长: \(recorder.currentTime)秒")
        }

        // 注意：使用 .record category + UIBackgroundModes: audio 时
        // 系统会自动保持录音在后台运行，不需要手动管理后台任务
        // 后台任务主要用于短暂的清理工作
    }
    
    @objc private func applicationWillEnterForeground() {
        guard let recorder = recorder else { return }
        
        print("📱 应用回到前台，检查录音状态...")
        
        // 确保录音器仍在运行
        if !recorder.isRecording {
            print("⚠️ 录音器已停止，尝试重新启动...")
            do {
                try configureSession()
                if recorder.record() {
                    print("✅ 录音器重新启动成功")
                } else {
                    print("❌ 录音器重新启动失败")
                }
            } catch {
                print("⚠️ 前台录音会话配置失败: \(error)")
            }
        } else {
            print("✅ 录音器仍在运行，当前时长: \(recorder.currentTime)秒")
        }
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // 中断开始 - 录音会自动暂停
            print("⚠️ 音频会话中断开始（可能是其他应用占用了音频）")
            // 不立即停止录音，等待中断结束

        case .ended:
            // 中断结束 - 尝试恢复录音
            print("✅ 音频会话中断结束，尝试恢复录音")

            // 检查是否应该恢复
            let shouldResume: Bool
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                shouldResume = options.contains(.shouldResume)
            } else {
                // 如果没有选项信息，默认尝试恢复
                shouldResume = true
            }

            if shouldResume, let recorder = recorder {
                // 使用重试机制恢复录音
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.attemptResumeRecording(retryCount: 3)
                }
            }

        @unknown default:
            break
        }
    }

    private func attemptResumeRecording(retryCount: Int) {
        guard retryCount > 0, let recorder = recorder else { return }

        do {
            // 重新配置并激活音频会话
            try configureSession()

            // 检查录音器状态并恢复
            if !recorder.isRecording {
                let resumed = recorder.record()
                if resumed {
                    print("✅ 录音恢复成功（剩余重试次数: \(retryCount)）")
                    print("📊 当前录音时长: \(recorder.currentTime)秒")

                    // 确保UI更新继续工作
                    if displayLink == nil {
                        activateDisplayLink()
                    }
                    if timer == nil {
                        activateTimer()
                    }
                } else {
                    print("⚠️ 录音恢复失败，\(retryCount - 1) 次后重试")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.attemptResumeRecording(retryCount: retryCount - 1)
                    }
                }
            } else {
                print("✅ 录音器已在运行中")
                print("📊 当前录音时长: \(recorder.currentTime)秒")
            }
        } catch {
            print("❌ 恢复录音配置失败: \(error)")
            if retryCount > 1 {
                print("⚠️ \(retryCount - 1) 秒后重试")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.attemptResumeRecording(retryCount: retryCount - 1)
                }
            } else {
                print("❌ 录音恢复失败，已用尽所有重试")
                // 不通知失败，因为录音可能仍在后台继续
            }
        }
    }
    
    @objc private func handleAudioSessionRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // 耳机等设备断开，可能需要重新配置
            print("⚠️ 音频设备断开")
            
        default:
            break
        }
    }
    
    private func refreshBackgroundTask() {
        // 如果后台任务即将过期，重新申请
        if backgroundTaskID != .invalid {
            let remainingTime = UIApplication.shared.backgroundTimeRemaining
            if remainingTime < 10 {
                // 时间快用完了，重新申请
                endBackgroundTask()
                beginBackgroundTask()
            }
        }
    }
    
    private func beginBackgroundTask() {
        endBackgroundTask()
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    private func activateDisplayLink() {
        // 前台时使用 CADisplayLink（更流畅）
        displayLink = CADisplayLink(target: self, selector: #selector(updateDuration))
        displayLink?.add(to: .main, forMode: .common)
        displayLink?.isPaused = false
    }

    private func deactivateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func activateTimer() {
        // 使用 Timer 作为备用，在后台也能工作
        deactivateTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            // 定期更新录音时长和音量
            self.updateDuration()
        }
        RunLoop.current.add(timer!, forMode: .common)
        RunLoop.current.add(timer!, forMode: .default)
    }
    
    private func deactivateTimer() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func updateDuration() {
        guard let recorder = recorder else { return }

        // 检查录音器是否仍在运行（每10次检查一次，避免过于频繁）
        checkCount += 1
        if checkCount >= 10 {
            checkCount = 0
            if !recorder.isRecording {
                // 如果录音器停止了，尝试重新启动
                do {
                    try configureSession()
                    if recorder.record() {
                        print("✅ 录音器自动恢复")
                    }
                } catch {
                    print("⚠️ 录音器恢复失败: \(error)")
                }
            }
        }

        // 始终使用 recorder.currentTime，这是录音器实际记录的准确时长
        // 即使录音暂停，currentTime 也会保持在暂停时的值，不会继续增长
        let duration = recorder.currentTime

        var level: Float = 0
        if recorder.isRecording {
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            let linearLevel = pow(10, power / 20)
            level = max(0, min(1, linearLevel))
        }

        delegate?.recorderDidUpdate(duration: duration, level: level)

        // 更新 Live Activity（iOS 16.1+）
        // if #available(iOS 16.1, *) {
        //     RecordingLiveActivityService.shared.update(duration: duration, level: level)
        // }
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        endBackgroundTask()
        deactivateDisplayLink()
        deactivateTimer()
        delegate?.recorderDidFinish(successfully: flag, fileURL: flag ? recorder.url : nil)
    }

    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        endBackgroundTask()
        deactivateDisplayLink()
        deactivateTimer()
        if let error {
            delegate?.recorderDidFail(error)
        } else {
            delegate?.recorderDidFail(RecorderError.unknown)
        }
    }
}

public enum RecorderError: Error {
    case failedToStart
    case sessionBusy
    case unknown
}

extension RecorderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToStart:
            return LocalizedStringKey.recorderFailedToStart.localized
        case .sessionBusy:
            return LocalizedStringKey.recorderSessionBusy.localized
        case .unknown:
            return LocalizedStringKey.recorderUnknownError.localized
        }
    }
}


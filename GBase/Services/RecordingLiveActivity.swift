import Foundation
import ActivityKit
import SwiftUI

// MARK: - Live Activity 数据模型

/// 录音 Live Activity 的属性（静态数据）
struct RecordingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// 当前录音时长（秒）
        var duration: TimeInterval
        /// 录音音量等级 (0.0 - 1.0)
        var level: Float
        /// 录音状态
        var status: RecordingStatus
    }

    /// 录音标题
    var title: String
}

/// 录音状态
enum RecordingStatus: String, Codable {
    case recording = "录音中"
    case paused = "已暂停"
}

// MARK: - Live Activity 管理服务

@available(iOS 16.1, *)
final class RecordingLiveActivityService {

    static let shared = RecordingLiveActivityService()

    private var currentActivity: Activity<RecordingActivityAttributes>?

    private init() {}

    /// 启动 Live Activity
    /// - Parameters:
    ///   - title: 录音标题
    /// - Returns: 是否成功启动
    @discardableResult
    func start(title: String = "语音录音") -> Bool {
        // 检查是否支持 Live Activity
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activity 未启用")
            return false
        }

        // 如果已有活动，先停止
        stop()

        let attributes = RecordingActivityAttributes(title: title)
        let initialState = RecordingActivityAttributes.ContentState(
            duration: 0,
            level: 0,
            status: .recording
        )

        do {
            let activity = try Activity<RecordingActivityAttributes>.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
            currentActivity = activity
            print("✅ Live Activity 启动成功")
            return true
        } catch {
            print("❌ Live Activity 启动失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 更新 Live Activity 状态
    /// - Parameters:
    ///   - duration: 录音时长
    ///   - level: 音量等级
    func update(duration: TimeInterval, level: Float) {
        guard let activity = currentActivity else {
            print("⚠️ 没有活跃的 Live Activity")
            return
        }

        Task {
            let updatedState = RecordingActivityAttributes.ContentState(
                duration: duration,
                level: level,
                status: .recording
            )

            await activity.update(using: updatedState)
        }
    }

    /// 停止 Live Activity
    func stop() {
        guard let activity = currentActivity else { return }

        Task {
            // 使用 .immediate 立即结束，或者使用 .after() 延迟结束
            await activity.end(dismissalPolicy: .immediate)
            currentActivity = nil
            print("✅ Live Activity 已停止")
        }
    }

    /// 结束 Live Activity（带最终状态显示）
    /// - Parameter duration: 最终录音时长
    func finish(duration: TimeInterval) {
        guard let activity = currentActivity else { return }

        Task {
            let finalState = RecordingActivityAttributes.ContentState(
                duration: duration,
                level: 0,
                status: .recording
            )

            // 更新最终状态，然后在4秒后自动消失
            await activity.end(using: finalState, dismissalPolicy: .after(.now + 4))
            currentActivity = nil
            print("✅ Live Activity 已完成")
        }
    }
}

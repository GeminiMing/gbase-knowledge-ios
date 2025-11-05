import SwiftUI
import ActivityKit
import WidgetKit

// MARK: - Live Activity UI

@available(iOS 16.1, *)
struct RecordingLiveActivityView: View {
    let context: ActivityViewContext<RecordingActivityAttributes>

    var body: some View {
        VStack(spacing: 0) {
            // 锁屏和通知中心的紧凑视图
            HStack(spacing: 12) {
                // 录音图标（动画）
                RecordingIndicator(isAnimating: context.state.status == .recording)

                // 录音信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(formatDuration(context.state.duration))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                // 音量指示器
                AudioLevelIndicator(level: context.state.level)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .activityBackgroundTint(Color(red: 0.98, green: 0.98, blue: 1.0))
        .activitySystemActionForegroundColor(.blue)
    }

    // 格式化录音时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - 录音指示器（红点动画）

struct RecordingIndicator: View {
    let isAnimating: Bool

    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 10, height: 10)
            .opacity(isAnimating ? opacity : 1.0)
            .onAppear {
                if isAnimating {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        opacity = 0.3
                    }
                }
            }
    }
}

// MARK: - 音量指示器

struct AudioLevelIndicator: View {
    let level: Float

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: barHeight(for: index))
                    .opacity(level > Float(index) * 0.2 ? 1.0 : 0.3)
            }
        }
        .frame(height: 20)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [8, 12, 16, 12, 8]
        return heights[index]
    }

    private func barColor(for index: Int) -> Color {
        if level > 0.8 {
            return .red
        } else if level > 0.5 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - 灵动岛配置

@available(iOS 16.2, *)
struct RecordingLiveActivityConfiguration: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            // 锁屏/通知中心的视图
            RecordingLiveActivityView(context: context)
        } dynamicIsland: { context in
            // 灵动岛配置
            DynamicIsland {
                // 展开视图
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        RecordingIndicator(isAnimating: context.state.status == .recording)
                        Text(context.attributes.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    AudioLevelIndicator(level: context.state.level)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Spacer()
                        Text(formatDuration(context.state.duration))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            } compactLeading: {
                // 紧凑视图 - 左侧（红点）
                RecordingIndicator(isAnimating: context.state.status == .recording)
            } compactTrailing: {
                // 紧凑视图 - 右侧（时间）
                Text(formatCompactDuration(context.state.duration))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .monospacedDigit()
            } minimal: {
                // 最小视图（只有红点）
                RecordingIndicator(isAnimating: context.state.status == .recording)
            }
        }
    }

    // 格式化时长（完整版）
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // 格式化时长（紧凑版）
    private func formatCompactDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

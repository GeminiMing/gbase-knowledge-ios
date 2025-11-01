import SwiftUI

struct ProjectRecorderView: View {
    @Environment(\.diContainer) private var container
    @Environment(\.dismiss) private var dismiss

    let project: Project
    let meeting: Meeting

    @StateObject private var viewModel = RecorderViewModel()
    @State private var hasInitialized = false

    private var isRecording: Bool {
        if case .recording = viewModel.status { return true }
        return false
    }

    private var recordingDurationText: String {
        guard case let .recording(duration) = viewModel.status else { return "" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }

    private var uploadProgress: Double? {
        if case let .uploading(progress) = viewModel.status { return progress }
        return nil
    }

    private var isProcessing: Bool {
        switch viewModel.status {
        case .processing, .uploading:
            return true
        default:
            return false
        }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                    .padding(.horizontal)
                    .padding(.top, 8)

                if viewModel.localRecordings.isEmpty {
                    emptyStateView
                        .frame(maxHeight: .infinity)
                } else {
                    recordingsList
                }

                Spacer(minLength: 0)

                recordControls
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                        Text(LocalizedStringKey.recorderBack.localized)
                    }
                }
                .tint(.primary)
            }
        }
        .alert(isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Alert(title: Text(LocalizedStringKey.commonError.localized),
                  message: Text(viewModel.errorMessage ?? LocalizedStringKey.recorderUnknownError.localized),
                  dismissButton: .default(Text(LocalizedStringKey.commonOk.localized)))
        }
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            viewModel.configure(container: container, shouldLoadProjects: false)
            viewModel.prepare(for: project, meeting: meeting)
        }
        .onDisappear {
            container.audioPlayerService.stop()
            container.audioRecorderService.cancelRecording(delete: false)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.title)
                .font(.title2)
                .fontWeight(.semibold)
            Text("\(LocalizedStringKey.recorderMeetingId.localized)\(meeting.id)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text(LocalizedStringKey.recorderNoRecordings.localized)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(LocalizedStringKey.recorderStartRecordingHint.localized)
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
        }
    }

    private var recordingsList: some View {
        List {
            ForEach(viewModel.localRecordings) { recording in
                recordingRow(for: recording)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func recordingRow(for recording: Recording) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button {
                    viewModel.togglePlayback(recording: recording)
                } label: {
                    Image(systemName: viewModel.isPlaying(recording: recording) ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Text(recording.fileName)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        Label(format(duration: recording.duration), systemImage: "clock")
                        Text("•")
                        Text(format(date: recording.createdAt))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Menu {
                    if recording.uploadStatus != .completed {
                        Button {
                            Task { await viewModel.retryUpload(recording: recording) }
                        } label: {
                            Label(LocalizedStringKey.recorderRetryUpload.localized, systemImage: "arrow.clockwise")
                        }
                    }
                    Button(role: .destructive) {
                        Task { await viewModel.delete(recording: recording) }
                    } label: {
                        Label(LocalizedStringKey.recorderDelete.localized, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            .padding(.vertical, 12)

            if recording.uploadStatus == .uploading || recording.uploadStatus == .pending {
                uploadProgressView(for: recording)
                    .padding(.top, 8)
            } else if recording.uploadStatus == .failed {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(LocalizedStringKey.recorderUploadFailed.localized)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func uploadProgressView(for recording: Recording) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(recording.uploadStatus.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: LocalizedStringKey.recorderUploadProgress.localized, Int(recording.uploadProgress)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                        .clipShape(Capsule())

                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * CGFloat(recording.uploadProgress) / 100, height: 4)
                        .clipShape(Capsule())
                        .animation(.linear(duration: 0.2), value: recording.uploadProgress)
                }
            }
            .frame(height: 4)
        }
    }

    private var recordControls: some View {
        VStack(spacing: 20) {
            // 录音时长显示
            if isRecording {
                Text(recordingDurationText)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .monospacedDigit()
            }

            // 波形显示区域
            ZStack {
                if isRecording {
                    WaveformView(samples: viewModel.waveformSamples, color: .red)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 8) {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 1)
                            .overlay(
                                Rectangle()
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    .foregroundColor(.secondary.opacity(0.3))
                            )
                        Text(LocalizedStringKey.recorderPreparing.localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 80)

            // 录音按钮
            Button {
                toggleRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.accentColor)
                        .frame(width: 72, height: 72)
                        .shadow(color: (isRecording ? Color.red : Color.accentColor).opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .disabled(isProcessing || viewModel.preparedMeeting == nil)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func toggleRecording() {
        Task {
            if isRecording {
                await viewModel.stopRecording()
            } else {
                await viewModel.startRecording()
            }
        }
    }

    private func format(duration: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }

    private func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        ProjectRecorderView(project: Project(id: "1",
                                             title: "Product Meeting Notes",
                                             description: "",
                                             itemCount: 3,
                                             myRole: .owner,
                                             createdAt: Date(),
                                             updatedAt: Date()),
                            meeting: Meeting(id: "m1",
                                             projectId: "1",
                                             title: "Product Meeting Notes",
                                             description: nil,
                                             meetingTime: Date(),
                                             location: nil,
                                             duration: nil,
                                             status: .pending,
                                             hasRecording: false,
                                             hasTranscript: false,
                                             hasSummary: false,
                                             createdAt: Date(),
                                             updatedAt: Date()))
        .environment(\.diContainer, .preview)
        .environmentObject(DIContainer.preview.appState)
    }
}


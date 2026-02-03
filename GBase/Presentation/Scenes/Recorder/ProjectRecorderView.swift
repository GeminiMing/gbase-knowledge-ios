import SwiftUI
import UniformTypeIdentifiers

struct ProjectRecorderView: View {
    @Environment(\.diContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let project: Project
    let meeting: Meeting

    @State private var hasInitialized = false
    @State private var isImporterPresented = false

    private var viewModel: RecorderViewModel? {
        appState.recorderViewModel
    }

    private var isRecording: Bool {
        guard let viewModel else { return false }
        if case .recording = viewModel.status { return true }
        return false
    }

    private var recordingDurationText: String {
        guard let viewModel, case let .recording(duration) = viewModel.status else { return "" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }

    private var uploadProgress: Double? {
        guard let viewModel else { return nil }
        if case let .uploading(progress) = viewModel.status { return progress }
        return nil
    }

    private var isProcessing: Bool {
        guard let viewModel else { return false }
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

            if let viewModel = viewModel {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.horizontal)
                        .padding(.top, 8)

                    Spacer()

                    recordControls(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            } else {
                ProgressView("Loading...")
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
            get: { viewModel?.errorMessage != nil },
            set: { if !$0 { viewModel?.errorMessage = nil } }
        )) {
            Alert(title: Text(LocalizedStringKey.commonError.localized),
                  message: Text(viewModel?.errorMessage ?? LocalizedStringKey.recorderUnknownError.localized),
                  dismissButton: .default(Text(LocalizedStringKey.commonOk.localized)))
        }
        .onAppear {
            guard !hasInitialized, let viewModel = viewModel else { return }
            hasInitialized = true
            viewModel.configure(container: container, shouldLoadProjects: false)
            viewModel.prepare(for: project, meeting: meeting)
        }
        .onDisappear {
            // 只在停止播放，不停止录音
            // 录音应该在后台继续运行
            container.audioPlayerService.stop()
            // 注意：不在这里调用 cancelRecording，因为切换tab不应该停止录音
        }
        .onChange(of: viewModel?.status) { newValue in
            // 当上传完成后自动返回
            if let status = newValue, case .completed = status {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒让用户看到完成状态
                    await MainActor.run {
                        dismiss()
                    }
                }
            }
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

    private func recordControls(viewModel: RecorderViewModel) -> some View {
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
                toggleRecording(viewModel: viewModel)
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

            // 导入按钮
            if !isRecording {
                Button {
                    isImporterPresented = true
                } label: {
                    Label(LocalizedStringKey.recorderImportAudio.localized, systemImage: "square.and.arrow.down")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                .disabled(isProcessing || viewModel.preparedMeeting == nil)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [
                UTType.wav,
                UTType.mp3,
                UTType.mpeg4,
                UTType.mpeg4Audio,
                UTType(filenameExtension: "webm") ?? .audio
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await viewModel.importAudioFile(url: url)
                }
            case .failure(let error):
                print("Import failed: \(error.localizedDescription)")
            }
        }
    }

    private func toggleRecording(viewModel: RecorderViewModel) {
        Task {
            if isRecording {
                await viewModel.stopRecording()
            } else {
                await viewModel.startRecording()
            }
        }
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


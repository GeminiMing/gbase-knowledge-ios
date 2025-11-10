import SwiftUI

struct ProjectDetailView: View {
    @Environment(\.diContainer) private var container
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ProjectDetailViewModel

    let project: Project

    init(project: Project) {
        self.project = project
        _viewModel = StateObject(wrappedValue: ProjectDetailViewModel(projectId: project.id))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if viewModel.recordings.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.recordings) { recording in
                            recordingCard(recording: recording)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .refreshable {
            await viewModel.loadRecordings()
        }
        .task {
            viewModel.configure(container: container)
            print("📱 [ProjectDetailView] View appeared for project: \(project.title)")
            appState.selectedProject = project
            print("📱 [ProjectDetailView] Set appState.selectedProject to: \(String(describing: appState.selectedProject?.title))")
            await viewModel.loadRecordings()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRecordings"))) { _ in
            print("🔄 [ProjectDetailView] Received refresh notification, reloading recordings")
            Task {
                await viewModel.loadRecordings()
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Alert(title: Text(LocalizedStringKey.commonError.localized),
                  message: Text(viewModel.errorMessage ?? ""),
                  dismissButton: .default(Text(LocalizedStringKey.commonOk.localized)))
        }
    }

    private func recordingCard(recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(recording.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(formatDate(recording.createdAt))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    viewModel.togglePlayback(recording: recording)
                }) {
                    Image(systemName: viewModel.isPlaying(recording: recording) ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Label(viewModel.formatDuration(recording.duration), systemImage: "timer")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Label(viewModel.formatFileSize(recording.fileSize), systemImage: "doc")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // 显示上传状态
                if recording.uploadStatus == .completed {
                    Label("已上传", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if recording.uploadStatus == .uploading {
                    Label("上传中", systemImage: "arrow.up.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if recording.uploadStatus == .failed {
                    Label("失败", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // 如果录音还未上传,显示上传按钮
            if recording.uploadStatus == .pending || recording.uploadStatus == .failed {
                HStack {
                    NavigationLink(destination: DraftDetailView(recording: recording)) {
                        Label(LocalizedStringKey.draftDetailBindAndUpload.localized, systemImage: "link")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        Task {
                            await viewModel.deleteRecording(recording)
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // 已上传的录音只显示删除按钮
                HStack {
                    Spacer()
                    Button(action: {
                        Task {
                            await viewModel.deleteRecording(recording)
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("暂无录音")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("使用底部的录音按钮开始录制")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

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
            appState.selectedProject = project
            await viewModel.loadRecordings()
        }
        .onDisappear {
            // 当离开项目详情页时，停止音频播放并清除选中的项目
            viewModel.cleanup()
            appState.selectedProject = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRecordings"))) { _ in
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
        .alert(item: Binding<Recording?>(
            get: { viewModel.recordingToDelete },
            set: { newValue in
                // 只有在没有设置删除标志时才允许清空（即用户取消时）
                // 如果是确认删除，shouldDeleteRecording 会在 primaryButton action 中设置，
                // 然后由 deleteRecording 方法负责清空状态
                if newValue == nil {
                    // 只有在没有设置删除标志时才清空（用户点击取消）
                    if !viewModel.shouldDeleteRecording {
                        viewModel.recordingToDelete = nil
                    }
                } else {
                    // 设置新的录音时，重置删除标志
                    viewModel.shouldDeleteRecording = false
                    viewModel.recordingToDelete = newValue
                }
            }
        )) { recording in
            Alert(
                title: Text(LocalizedStringKey.deleteRecordingTitle.localized),
                message: Text(LocalizedStringKey.deleteRecordingMessage.localized),
                primaryButton: .destructive(Text(LocalizedStringKey.deleteRecordingConfirm.localized)) {
                    // 保存要删除的录音信息（在 Alert 关闭前保存，避免状态被清空）
                    let recordingToDelete = recording
                    // 先设置标志，防止 Alert 关闭时 set 被调用导致 recordingToDelete 被清空
                    viewModel.shouldDeleteRecording = true
                    // 执行删除操作，传入保存的 recording 副本
                    Task { @MainActor in
                        await viewModel.deleteRecording(recording: recordingToDelete)
                    }
                },
                secondaryButton: .cancel(Text(LocalizedStringKey.deleteRecordingCancel.localized)) {
                    // 取消删除，重置状态
                    viewModel.shouldDeleteRecording = false
                    viewModel.recordingToDelete = nil
                }
            )
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
                    Label(LocalizedStringKey.uploadStatusCompleted.localized, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if recording.uploadStatus == .uploading {
                    Label(LocalizedStringKey.uploadStatusUploading.localized, systemImage: "arrow.up.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if recording.uploadStatus == .failed {
                    Label(LocalizedStringKey.uploadStatusFailed.localized, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // 如果录音还未上传,显示上传按钮
            if recording.uploadStatus == .pending || recording.uploadStatus == .failed {
                HStack {
                    Button(action: {
                        Task {
                            await viewModel.bindAndUploadRecording(recording)
                        }
                    }) {
                        VStack(spacing: 4) {
                            if viewModel.uploadingRecordingId == recording.id {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                    Text(String(format: "%@ %d%%", LocalizedStringKey.uploadStatusUploading.localized, Int(viewModel.uploadProgress)))
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                            } else {
                                Label(LocalizedStringKey.draftDetailBindAndUpload.localized, systemImage: "link")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(viewModel.uploadingRecordingId == recording.id ? Color.orange : Color.blue)
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.uploadingRecordingId == recording.id)

                    Button(action: {
                        viewModel.confirmDeleteRecording(recording)
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
                        viewModel.confirmDeleteRecording(recording)
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

            Text(LocalizedStringKey.projectDetailNoRecordings.localized)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(LocalizedStringKey.projectDetailStartRecordingHint.localized)
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

import SwiftUI
import UniformTypeIdentifiers

struct DraftsView: View {
    @Environment(\.diContainer) private var container
    @StateObject private var viewModel = DraftsViewModel()
    @State private var isImporterPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.drafts.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.drafts) { draft in
                                NavigationLink(destination: DraftDetailView(recording: draft)) {
                                    draftCard(draft: draft)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey.draftsTitle.localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            .refreshable {
                await viewModel.loadDrafts()
            }
            .task {
                viewModel.configure(container: container)
                await viewModel.loadDrafts()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRecordings"))) { _ in
                Task {
                    await viewModel.loadDrafts()
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
                get: {
                    let value = viewModel.draftToDelete
                    print("📋 [DraftsView] Alert Binding get called, returning: \(value?.id ?? "nil")")
                    return value
                },
                set: { newValue, transaction in
                    print("📋 [DraftsView] Alert Binding set called with: \(newValue?.id ?? "nil")")
                    print("📋 [DraftsView] Current shouldDeleteDraft: \(viewModel.shouldDeleteDraft)")
                    
                    // 只有在没有设置删除标志时才允许清空（即用户取消时）
                    // 如果是确认删除，shouldDeleteDraft 会在 primaryButton action 中设置，
                    // 然后由 deleteDraft 方法负责清空状态
                    if newValue == nil {
                        // 只有在没有设置删除标志时才清空（用户点击取消）
                        if !viewModel.shouldDeleteDraft {
                            print("📋 [DraftsView] Clearing draftToDelete (user cancelled)")
                            viewModel.draftToDelete = nil
                        } else {
                            print("📋 [DraftsView] NOT clearing draftToDelete (deletion in progress)")
                        }
                    } else {
                        // 设置新的草稿时，重置删除标志
                        if let recording = newValue {
                            print("📋 [DraftsView] Setting new draftToDelete: \(recording.id)")
                            viewModel.shouldDeleteDraft = false
                            viewModel.draftToDelete = recording
                        }
                    }
                }
            )) { recording in
                Alert(
                    title: Text(LocalizedStringKey.deleteRecordingTitle.localized),
                    message: Text(LocalizedStringKey.deleteRecordingMessage.localized),
                    primaryButton: .destructive(Text(LocalizedStringKey.deleteRecordingConfirm.localized)) {
                        print("🗑️ [DraftsView] Delete confirmed for recording: \(recording.id)")
                        
                        // 保存要删除的录音信息（在 Alert 关闭前保存，避免状态被清空）
                        let recordingToDelete = recording
                        
                        // 先设置标志，防止 Alert 关闭时 set 被调用导致 draftToDelete 被清空
                        viewModel.shouldDeleteDraft = true
                        print("🗑️ [DraftsView] shouldDeleteDraft set to true")
                        print("🗑️ [DraftsView] draftToDelete before delete: \(viewModel.draftToDelete?.id ?? "nil")")
                        print("🗑️ [DraftsView] Using saved recording copy: \(recordingToDelete.id)")
                        
                        // 执行删除操作，传入保存的 recording 副本，不依赖状态
                        Task { @MainActor in
                            print("🗑️ [DraftsView] Starting delete task")
                            await viewModel.deleteDraft(recording: recordingToDelete)
                            print("🗑️ [DraftsView] Delete task completed")
                        }
                    },
                    secondaryButton: .cancel(Text(LocalizedStringKey.deleteRecordingCancel.localized)) {
                        print("❌ [DraftsView] Delete cancelled")
                        // 取消删除，重置状态
                        viewModel.shouldDeleteDraft = false
                        viewModel.draftToDelete = nil
                    }
                )
            }
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
    }

    private func draftCard(draft: Recording) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(draft.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(formatDate(draft.createdAt))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    viewModel.togglePlayback(recording: draft)
                }) {
                    Image(systemName: viewModel.isPlaying(recording: draft) ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Label(viewModel.formatDuration(draft.duration), systemImage: "timer")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Label(viewModel.formatFileSize(draft.fileSize), systemImage: "doc")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                NavigationLink(destination: DraftDetailView(recording: draft)) {
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
                    viewModel.confirmDeleteDraft(draft)
                }) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(LocalizedStringKey.draftsEmptyTitle.localized)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(LocalizedStringKey.draftsEmptyMessage.localized)
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

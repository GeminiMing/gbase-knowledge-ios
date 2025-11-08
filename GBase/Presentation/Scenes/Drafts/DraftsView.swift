import SwiftUI

struct DraftsView: View {
    @Environment(\.diContainer) private var container
    @StateObject private var viewModel = DraftsViewModel()
    @State private var selectedDraft: Recording?
    @State private var showingDetailSheet = false

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
                                draftCard(draft: draft)
                                    .onTapGesture {
                                        selectedDraft = draft
                                        showingDetailSheet = true
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey.draftsTitle.localized)
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
            .alert(isPresented: Binding<Bool>(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Alert(title: Text(LocalizedStringKey.commonError.localized),
                      message: Text(viewModel.errorMessage ?? ""),
                      dismissButton: .default(Text(LocalizedStringKey.commonOk.localized)))
            }
            .sheet(isPresented: $showingDetailSheet) {
                if let draft = selectedDraft {
                    DraftDetailView(recording: draft) {
                        showingDetailSheet = false
                        Task { await viewModel.loadDrafts() }
                    }
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
                Button(action: {
                    selectedDraft = draft
                    showingDetailSheet = true
                }) {
                    Label(LocalizedStringKey.draftDetailBindAndUpload.localized, systemImage: "link")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                }

                Button(action: {
                    Task {
                        await viewModel.deleteDraft(draft)
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

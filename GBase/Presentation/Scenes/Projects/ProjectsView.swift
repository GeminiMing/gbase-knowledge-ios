import SwiftUI

struct ProjectsView: View {
    @Environment(\.diContainer) private var container
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProjectsViewModel()
    @State private var isProcessingSelection = false
    @State private var destinationProject: Project?
    @State private var destinationMeeting: Meeting?
    @State private var navigateToRecorder = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 搜索框
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .background(Color(.systemGroupedBackground))

                    // 项目列表
                    if viewModel.filteredProjects.isEmpty && !viewModel.isLoading {
                        emptyStateView
                            .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(viewModel.filteredProjects.enumerated()), id: \.element.id) { index, project in
                                    projectCard(project: project)
                                        .onTapGesture {
                                            handleSelection(project)
                                        }
                                        .onAppear {
                                            if index == viewModel.filteredProjects.count - 1 {
                                                Task { await viewModel.loadMore() }
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToRecorder) {
                if let project = destinationProject, let meeting = destinationMeeting {
                    ProjectRecorderView(project: project, meeting: meeting)
                } else {
                    EmptyView()
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.projects.isEmpty {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                if isProcessingSelection {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        ProgressView("创建会议中...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey.projectsTitle.localized)
            .refreshable {
                await viewModel.refresh()
            }
            .alert(isPresented: Binding<Bool>(
                get: { viewModel.errorMessage != nil },
                set: { newValue in
                    if !newValue { viewModel.errorMessage = nil }
                }
            )) {
                Alert(title: Text(LocalizedStringKey.commonError.localized),
                      message: Text(viewModel.errorMessage ?? LocalizedStringKey.recorderUnknownError.localized),
                      dismissButton: .default(Text(LocalizedStringKey.commonOk.localized)))
            }
        }
        .onAppear {
            viewModel.configure(container: container)
            Task { await viewModel.refresh() }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))

            TextField(LocalizedStringKey.projectsSearchPlaceholder.localized, text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .onSubmit {
                    Task { await viewModel.refresh() }
                }

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(viewModel.searchText.isEmpty ? LocalizedStringKey.projectsEmptyTitle.localized : LocalizedStringKey.projectsSearchEmptyTitle.localized)
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !viewModel.searchText.isEmpty {
                Text(LocalizedStringKey.projectsSearchEmptyMessage.localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    private func projectCard(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和角色标签
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.title)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if !project.description.isEmpty {
                        Text(project.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                // 角色标签
                Text(roleDisplayName(project.myRole))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(roleColor(project.myRole))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(roleColor(project.myRole).opacity(0.15))
                    .clipShape(Capsule())
            }

            // 底部信息
            HStack(spacing: 16) {
                Label("\(project.itemCount)", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private func roleDisplayName(_ role: ProjectRole) -> String {
        switch role {
        case .owner:
            return LocalizedStringKey.projectRoleOwner.localized
        case .contributor:
            return LocalizedStringKey.projectRoleContributor.localized
        case .sharee:
            return LocalizedStringKey.projectRoleSharee.localized
        }
    }

    private func roleColor(_ role: ProjectRole) -> Color {
        switch role {
        case .owner:
            return .blue
        case .contributor:
            return .green
        case .sharee:
            return .orange
        }
    }

    private func handleSelection(_ project: Project) {
        guard !isProcessingSelection else { return }
        isProcessingSelection = true

        Task {
            do {
                let meeting = try await container.createMeetingUseCase.execute(projectId: project.id,
                                                                                title: project.title.isEmpty ? LocalizedStringKey.projectsTemporaryMeeting.localized : project.title,
                                                                                meetingTime: Date(),
                                                                                location: nil,
                                                                                description: nil)

                await MainActor.run {
                    destinationProject = project
                    destinationMeeting = meeting
                    appState.selectedProject = project
                    navigateToRecorder = true
                    isProcessingSelection = false
                }
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                    isProcessingSelection = false
                }
            }
        }
    }
}

#Preview {
    ProjectsView()
        .environment(\.diContainer, .preview)
        .environmentObject(DIContainer.preview.appState)
}


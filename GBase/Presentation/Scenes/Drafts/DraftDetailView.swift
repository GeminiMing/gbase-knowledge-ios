import SwiftUI
import Combine

struct DraftDetailView: View {
    @Environment(\.diContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DraftDetailViewModel

    let recording: Recording
    let onDismiss: () -> Void

    init(recording: Recording, onDismiss: @escaping () -> Void) {
        self.recording = recording
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: DraftDetailViewModel(recording: recording))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(LocalizedStringKey.draftDetailRecordingInfo.localized)) {
                    HStack {
                        Text(LocalizedStringKey.draftDetailFileName.localized)
                        Spacer()
                        Text(recording.fileName)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    HStack {
                        Text(LocalizedStringKey.draftDetailDuration.localized)
                        Spacer()
                        Text(formatDuration(recording.duration))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(LocalizedStringKey.draftDetailFileSize.localized)
                        Spacer()
                        Text(formatFileSize(recording.fileSize))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(LocalizedStringKey.draftDetailCreatedAt.localized)
                        Spacer()
                        Text(formatDate(recording.createdAt))
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text(LocalizedStringKey.draftDetailCustomName.localized)) {
                    TextField(LocalizedStringKey.draftDetailCustomNamePlaceholder.localized, text: $viewModel.customName)
                }

                Section(header: Text(LocalizedStringKey.draftDetailSelectProject.localized)) {
                    if viewModel.projects.isEmpty {
                        Text(LocalizedStringKey.draftDetailNoProjects.localized)
                            .foregroundColor(.secondary)
                    } else {
                        Picker(LocalizedStringKey.draftDetailProject.localized, selection: $viewModel.selectedProjectId) {
                            Text(LocalizedStringKey.draftDetailPleaseSelect.localized).tag(nil as String?)
                            ForEach(viewModel.projects, id: \.id) { project in
                                Text(project.title).tag(project.id as String?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section {
                    Button(action: {
                        Task {
                            await viewModel.bindToProject()
                            if viewModel.bindingSuccess {
                                onDismiss()
                                dismiss()
                            }
                        }
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isBinding {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Text(LocalizedStringKey.draftDetailBinding.localized)
                                    .padding(.leading, 8)
                            } else {
                                Text(LocalizedStringKey.draftDetailBindAndUpload.localized)
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.selectedProjectId == nil || viewModel.isBinding)
                }
            }
            .navigationTitle(LocalizedStringKey.draftDetailTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey.commonCancel.localized) {
                        dismiss()
                    }
                }
            }
            .task {
                viewModel.configure(container: container)
                await viewModel.loadProjects()
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
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024

        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.1f KB", kb)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

@MainActor
final class DraftDetailViewModel: ObservableObject {
    struct ProjectOption: Identifiable {
        let id: String
        let title: String
    }

    @Published var projects: [ProjectOption] = []
    @Published var selectedProjectId: String?
    @Published var customName: String = ""
    @Published var isBinding: Bool = false
    @Published var bindingSuccess: Bool = false
    @Published var errorMessage: String?

    private var container: DIContainer?
    private let recording: Recording

    init(recording: Recording) {
        self.recording = recording
        self.customName = recording.customName ?? ""
    }

    func configure(container: DIContainer) {
        self.container = container
    }

    func loadProjects() async {
        guard let container else {
            errorMessage = LocalizedStringKey.profileDependencyNotInjected.localized
            return
        }

        do {
            let map = try await container.fetchEditableProjectsUseCase.execute()
            projects = map.map { ProjectOption(id: $0.key, title: $0.value) }
                          .sorted { $0.title < $1.title }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func bindToProject() async {
        guard let container, let projectId = selectedProjectId else { return }

        isBinding = true
        defer { isBinding = false }

        do {
            // Create a meeting for this recording
            let meetingTitle = customName.isEmpty ? "\(LocalizedStringKey.quickRecorderDefaultName.localized) - \(formatDate(recording.createdAt))" : customName
            let meeting = try await container.createMeetingUseCase.execute(
                projectId: projectId,
                title: meetingTitle,
                meetingTime: recording.createdAt,
                location: nil,
                description: LocalizedStringKey.draftDetailBindingDescription.localized
            )

            // Bind the draft to the project and meeting
            let finalName = customName.isEmpty ? nil : customName
            try container.bindDraftToProjectUseCase.execute(
                recordingId: recording.id,
                projectId: projectId,
                meetingId: meeting.id,
                customName: finalName
            )

            // Fetch the updated recording
            let recordings = try container.recordingLocalStore.fetch(projectId: nil, status: nil)
            guard let updatedRecording = recordings.first(where: { $0.id == recording.id }) else {
                errorMessage = LocalizedStringKey.draftDetailRecordingNotFound.localized
                return
            }

            // Upload the recording
            try await uploadRecording(updatedRecording)

            bindingSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uploadRecording(_ recording: Recording) async throws {
        guard let container else { throw APIError.networkUnavailable }
        guard let meetingId = recording.meetingId else { return }

        let fileURL = URL(fileURLWithPath: recording.localFilePath)
        let actualStart = recording.actualStartAt ?? Date()
        let actualEnd = recording.actualEndAt ?? Date()

        _ = try await container.recordingUploadService.uploadRecording(
            meetingId: meetingId,
            fileURL: fileURL,
            actualStartAt: actualStart,
            actualEndAt: actualEnd,
            fileType: "COMPLETE_RECORDING_FILE",
            fromType: "GBASE",
            customName: recording.customName,
            progressHandler: { [weak self] progress in
                Task { @MainActor in
                    try? container.recordingLocalStore.update(
                        id: recording.id,
                        status: progress >= 100 ? .completed : .uploading,
                        progress: progress
                    )
                }
            }
        )

        try container.recordingLocalStore.update(id: recording.id, status: .completed, progress: 100)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

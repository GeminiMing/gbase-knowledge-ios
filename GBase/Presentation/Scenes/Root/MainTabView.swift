import SwiftUI

struct MainTabView: View {
    @Environment(\.diContainer) private var container
    @EnvironmentObject private var appState: AppState
    @State private var showingQuickRecorder = false
    @State private var recordingMeeting: Meeting?
    @State private var previousTab: AppState.MainTab = .projects

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                ProjectsView()
                    .tag(AppState.MainTab.projects)
                    .toolbar(.hidden, for: .tabBar)
                
                DraftsView()
                    .tag(AppState.MainTab.drafts)
                    .toolbar(.hidden, for: .tabBar)
                    .onAppear {
                        if appState.selectedTab == .drafts {
                            print("📑 [MainTabView] Switched to drafts tab, clearing selectedProject")
                            appState.selectedProject = nil
                        }
                    }
                
                ProfileView()
                    .tag(AppState.MainTab.profile)
                    .toolbar(.hidden, for: .tabBar)
                    .onAppear {
                        if appState.selectedTab == .profile {
                            print("👤 [MainTabView] Switched to profile tab, clearing selectedProject")
                            appState.selectedProject = nil
                        }
                    }
                
                // 保留 Recorder tab 作为占位，防止逻辑断裂，但不在 UI 上显示
                Color.clear
                    .tag(AppState.MainTab.recorder)
                    .toolbar(.hidden, for: .tabBar)
            }
            
            // 自定义 TabBar
            CustomTabBar(selectedTab: $appState.selectedTab) {
                handleRecordButtonTap()
            }
            .padding(.bottom, 20) // 底部留出一些空间
        }
        .navigationTitle(appState.authContext?.user.name ?? "")
        .onChange(of: appState.selectedTab) { newTab in
            if newTab == .recorder {
                handleRecordButtonTap()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if appState.selectedTab == .recorder {
                        appState.selectedTab = previousTab
                    }
                }
            } else if newTab != .recorder {
                previousTab = newTab
            }
        }
        .sheet(isPresented: $showingQuickRecorder, onDismiss: {
            // 录音完成后发送通知,让ProjectDetailView刷新
            print("🔄 [MainTabView] Recording sheet dismissed, posting refresh notification")
            NotificationCenter.default.post(name: NSNotification.Name("RefreshRecordings"), object: nil)

            // 确保重置录音状态,以便下次能正常开始
            if let viewModel = appState.recorderViewModel {
                print("🔄 [MainTabView] Resetting recorder status to idle")
                Task { @MainActor in
                    viewModel.status = .idle
                }
            }
        }) {
            if let viewModel = appState.recorderViewModel {
                QuickRecorderView(viewModel: viewModel, meeting: recordingMeeting)
            }
        }
    }

    private func handleRecordButtonTap() {
        guard let viewModel = appState.recorderViewModel else { return }

        print("🔴 [MainTabView] Quick record button clicked")
        print("🔴 [MainTabView] appState.selectedProject: \(String(describing: appState.selectedProject))")
        print("🔴 [MainTabView] Current tab: \(appState.selectedTab)")

        // 先显示弹窗，然后在后台创建会议
        showingQuickRecorder = true
        
        // 如果有选中的项目,为该项目创建会议并绑定（在后台异步执行）
        if let project = appState.selectedProject {
            print("✅ [MainTabView] Project found: \(project.title)")
            Task {
                do {
                    let meeting = try await container.createMeetingUseCase.execute(
                        projectId: project.id,
                        title: project.title.isEmpty ? "快速录音" : project.title,
                        meetingTime: Date(),
                        location: nil,
                        description: nil
                    )
                    await MainActor.run {
                        recordingMeeting = meeting
                        viewModel.prepare(for: project, meeting: meeting)
                    }
                } catch {
                    print("❌ 创建会议失败: \(error)")

                    // 检查是否是网络错误
                    if let apiError = error as? APIError, apiError == .networkUnavailable {
                        // 网络不可用时，显示错误但仍允许作为草稿录音
                        print("⚠️ [MainTabView] Network unavailable, switching to draft mode")
                        await MainActor.run {
                            viewModel.errorMessage = apiError.localizedDescription
                        }
                    }

                    // 如果创建会议失败,允许录音,但作为草稿
                    await MainActor.run {
                        recordingMeeting = nil
                        viewModel.prepareForQuickRecording()
                    }
                }
            }
        } else {
            // 没有选中项目,作为草稿录音
            print("⚠️ [MainTabView] No project selected, using draft mode")
            recordingMeeting = nil
            viewModel.prepareForQuickRecording()
        }
    }
}

// Quick Recorder Sheet View
struct QuickRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: RecorderViewModel
    let meeting: Meeting?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Waveform visualization
                HStack(spacing: 4) {
                    ForEach(Array(viewModel.waveformSamples.enumerated()), id: \.offset) { _, level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "00a4d6"))
                            .frame(width: 6, height: max(20, level * 100))
                    }
                }
                .frame(height: 120)

                // Timer
                if case .recording(let duration) = viewModel.status {
                    Text(formatDuration(duration))
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundColor(.primary)
                } else {
                    Text("00:00")
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Record/Stop button
                Button(action: {
                    Task {
                        if case .recording = viewModel.status {
                            await viewModel.stopRecording()
                            // 如果是草稿模式，不自动关闭，等待用户选择是否保存到项目
                            if !viewModel.isDraftMode {
                                dismiss()
                            }
                        } else {
                            await viewModel.startRecording()
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "00a4d6"))
                            .frame(width: 80, height: 80)

                        if case .recording = viewModel.status {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: 28, height: 28)
                        } else if case .idle = viewModel.status {
                            // Show mic icon when idle (waiting to start)
                            Image(systemName: "mic.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        } else {
                            // Show loading indicator for processing
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .padding()
            .navigationTitle(meeting != nil ? (viewModel.selectedProjectTitle ?? LocalizedStringKey.quickRecorderTitle.localized) : LocalizedStringKey.quickRecorderTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey.commonCancel.localized) {
                        // 如果正在录音,停止但不保存
                        if case .recording = viewModel.status {
                            Task {
                                // 直接停止录音服务,不触发保存逻辑
                                viewModel.cancelRecording()
                            }
                        }
                        dismiss()
                    }
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
            .sheet(isPresented: Binding<Bool>(
                get: { viewModel.showSaveToProjectAlert },
                set: { if !$0 { viewModel.dismissSaveToProjectAlert() } }
            )) {
                SaveToProjectSheet(viewModel: viewModel)
            }
            .onAppear {
                // 自动开始录音（只在没有错误的情况下）
                Task {
                    if case .idle = viewModel.status, viewModel.errorMessage == nil {
                        print("🎤 [QuickRecorderView] Auto-starting recording on appear")
                        await viewModel.startRecording()
                    } else if viewModel.errorMessage != nil {
                        print("⚠️ [QuickRecorderView] Skipping auto-start due to existing error")
                    }
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// Save to Project Sheet
struct SaveToProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.diContainer) private var container
    @ObservedObject var viewModel: RecorderViewModel
    @State private var projects: [RecorderViewModel.ProjectOption] = []
    @State private var isLoadingProjects = true
    
    var body: some View {
        NavigationStack {
            Form {
                // 显示错误消息(如果有)
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                    }
                }

                Section(header: Text(LocalizedStringKey.draftDetailSelectProject.localized)) {
                    if isLoadingProjects {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if projects.isEmpty {
                        Text(LocalizedStringKey.draftDetailNoProjects.localized)
                            .foregroundColor(.secondary)
                    } else {
                        Picker(LocalizedStringKey.draftDetailProject.localized, selection: Binding<String?>(
                            get: { viewModel.saveToProjectSelectedProjectId },
                            set: { viewModel.saveToProjectSelectedProjectId = $0 }
                        )) {
                            Text(LocalizedStringKey.draftDetailPleaseSelect.localized).tag(nil as String?)
                            ForEach(projects) { project in
                                Text(project.title).tag(project.id as String?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section {
                    Button(action: {
                        // 清除之前的错误消息
                        viewModel.errorMessage = nil
                        Task {
                            await viewModel.saveDraftToProject()
                            // 只有在成功(没有错误)时才关闭
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isBindingToProject {
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
                    .disabled(viewModel.saveToProjectSelectedProjectId == nil || viewModel.isBindingToProject)
                }
            }
            .navigationTitle(LocalizedStringKey.recorderSaveToProject.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey.recorderSaveLater.localized) {
                        viewModel.dismissSaveToProjectAlert()
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await loadProjects()
                }
            }
        }
    }
    
    private func loadProjects() async {
        isLoadingProjects = true
        defer { isLoadingProjects = false }
        
        do {
            let map = try await container.fetchEditableProjectsUseCase.execute()
            projects = map.map { RecorderViewModel.ProjectOption(id: $0.key, title: $0.value) }
                          .sorted { $0.title < $1.title }
        } catch {
            // Handle error silently or show error message
            print("Failed to load projects: \(error)")
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.diContainer, .preview)
        .environmentObject(DIContainer.preview.appState)
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppState.MainTab
    var onRecordTap: () -> Void
    
    @Namespace private var animationNamespace
    
    var body: some View {
        HStack(spacing: 8) { // 减小中间间隙
            // 左侧分组：Projects, Drafts, Profile
            HStack(spacing: 0) {
                TabBarButton(tab: .projects, selectedTab: $selectedTab, namespace: animationNamespace)
                    .frame(maxWidth: .infinity)
                TabBarButton(tab: .drafts, selectedTab: $selectedTab, namespace: animationNamespace)
                    .frame(maxWidth: .infinity)
                TabBarButton(tab: .profile, selectedTab: $selectedTab, namespace: animationNamespace)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 64)
            .padding(.horizontal, 4)
            .background(
                Capsule()
                    .fill(.regularMaterial)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            
            // 右侧录音按钮
            Button(action: onRecordTap) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.primary)
                    .frame(width: 64, height: 64)
                    .background(.regularMaterial)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct TabBarButton: View {
    let tab: AppState.MainTab
    @Binding var selectedTab: AppState.MainTab
    var namespace: Namespace.ID
    
    var iconName: String {
        switch tab {
        case .projects: return "folder"
        case .drafts: return "tray"
        case .profile: return "person.circle"
        default: return ""
        }
    }
    
    var title: String {
        switch tab {
        case .projects: return LocalizedStringKey.tabProjects.localized
        case .drafts: return LocalizedStringKey.tabDrafts.localized
        case .profile: return LocalizedStringKey.tabProfile.localized
        default: return ""
        }
    }
    
    var isSelected: Bool {
        selectedTab == tab
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: isSelected && tab != .projects ? iconName + ".fill" : iconName)
                    .font(.system(size: 22))
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .blue : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .matchedGeometryEffect(id: "TabBackground", in: namespace)
                    }
                }
            )
        }
    }
}


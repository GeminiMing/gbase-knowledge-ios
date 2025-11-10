import SwiftUI
import WebKit

struct MainTabView: View {
    @Environment(\.diContainer) private var container
    @EnvironmentObject private var appState: AppState
    @State private var showingQuickRecorder = false
    @State private var recordingMeeting: Meeting?

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ProjectsView()
                .tabItem {
                    Label(LocalizedStringKey.tabProjects.localized, systemImage: "folder")
                }
                .tag(AppState.MainTab.projects)

            DraftsView()
                .tabItem {
                    Label(LocalizedStringKey.tabDrafts.localized, systemImage: "tray")
                }
                .tag(AppState.MainTab.drafts)
                .onAppear {
                    // 切换到草稿页时清除选中的项目
                    if appState.selectedTab == .drafts {
                        print("📑 [MainTabView] Switched to drafts tab, clearing selectedProject")
                        appState.selectedProject = nil
                    }
                }

            // Center recorder button in tab bar
            Color.clear
                .tabItem {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "00a4d6"))
                            .frame(width: 56, height: 56)
                            .shadow(color: Color(hex: "00a4d6").opacity(0.3), radius: 4, x: 0, y: 2)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    .offset(y: -8)
                }
                .tag(AppState.MainTab.recorder)

            ProfileView()
                .tabItem {
                    Label(LocalizedStringKey.tabProfile.localized, systemImage: "person.circle")
                }
                .tag(AppState.MainTab.profile)
                .onAppear {
                    // 切换到个人页时清除选中的项目
                    if appState.selectedTab == .profile {
                        print("👤 [MainTabView] Switched to profile tab, clearing selectedProject")
                        appState.selectedProject = nil
                    }
                }

            // Web view for hub.gbase.ai as a full page
            HubView()
            .tabItem {
                Label("Hub", systemImage: "globe")
            }
            .tag(AppState.MainTab.hub)
        }
        .navigationTitle(appState.authContext?.user.name ?? "")
        .onChange(of: appState.selectedTab) { newTab in
            // Intercept recorder tab selection
            if newTab == .recorder {
                handleRecordButtonTap()
                // Reset to previous valid tab
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if appState.selectedTab == .recorder {
                        appState.selectedTab = .projects
                    }
                }
            }
        }
        .sheet(isPresented: $showingQuickRecorder, onDismiss: {
            // 录音完成后发送通知,让ProjectDetailView刷新
            print("🔄 [MainTabView] Recording sheet dismissed, posting refresh notification")
            NotificationCenter.default.post(name: NSNotification.Name("RefreshRecordings"), object: nil)
        }) {
            if let viewModel = appState.recorderViewModel {
                QuickRecorderView(viewModel: viewModel, meeting: recordingMeeting)
            }
        }
    }

    private func handleRecordButtonTap() {
        Task {
            guard let viewModel = appState.recorderViewModel else { return }

            print("🔴 [MainTabView] Quick record button clicked")
            print("🔴 [MainTabView] appState.selectedProject: \(String(describing: appState.selectedProject))")
            print("🔴 [MainTabView] Current tab: \(appState.selectedTab)")

            // 如果有选中的项目,为该项目创建会议并绑定
            if let project = appState.selectedProject {
                print("✅ [MainTabView] Project found: \(project.title)")
                do {
                    let meeting = try await container.createMeetingUseCase.execute(
                        projectId: project.id,
                        title: project.title.isEmpty ? "快速录音" : project.title,
                        meetingTime: Date(),
                        location: nil,
                        description: nil
                    )
                    recordingMeeting = meeting
                    viewModel.prepare(for: project, meeting: meeting)
                } catch {
                    print("❌ 创建会议失败: \(error)")
                    // 如果创建会议失败,仍然允许录音,但作为草稿
                    recordingMeeting = nil
                    viewModel.prepareForQuickRecording()
                }
            } else {
                // 没有选中项目,作为草稿录音
                print("⚠️ [MainTabView] No project selected, using draft mode")
                recordingMeeting = nil
                viewModel.prepareForQuickRecording()
            }

            await MainActor.run {
                showingQuickRecorder = true
            }
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
                            dismiss()
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
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

#Preview {
    MainTabView()
        .environment(\.diContainer, .preview)
        .environmentObject(DIContainer.preview.appState)
}

// MARK: - HubView with Auto Login
struct HubView: View {
    @Environment(\.diContainer) private var container
    @State private var hubURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                if let url = hubURL {
                    WebView(url: url)
                } else {
                    ProgressView("Loading...")
                }
            }
            .navigationTitle("Hub")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadHubURL()
        }
    }

    private func loadHubURL() async {
        // Try to load saved credentials
        guard let credentials = try? await container.credentialsStore.loadCredentials() else {
            // No credentials, just load Hub without auto-login
            hubURL = URL(string: "https://hub.gbase.ai")
            return
        }

        // Build URL with auto-login parameters
        var components = URLComponents(string: "https://hub.gbase.ai/auth/login")!
        components.queryItems = [
            URLQueryItem(name: "auto_login", value: "1"),
            URLQueryItem(name: "auto_email", value: credentials.email),
            URLQueryItem(name: "auto_password", value: credentials.password),
            URLQueryItem(name: "auto_remember", value: "1")
        ]

        hubURL = components.url ?? URL(string: "https://hub.gbase.ai")
        print("🌐 [HubView] Loading Hub with auto-login for: \(credentials.email)")
    }
}

// MARK: - WebView
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // No update needed
    }
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


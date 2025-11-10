import SwiftUI

struct MainTabView: View {
    @Environment(\.diContainer) private var container
    @EnvironmentObject private var appState: AppState
    @State private var showingQuickRecorder = false
    @State private var recordingMeeting: Meeting?

    var body: some View {
        ZStack {
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
            }
            .navigationTitle(appState.authContext?.user.name ?? "")

            // Quick record floating button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    quickRecordButton
                        .padding(.trailing, 24)
                        .padding(.bottom, 80)
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

    private var quickRecordButton: some View {
        Button(action: {
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

                // Start recording immediately after showing the sheet
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds delay for sheet animation
                await viewModel.startRecording()
            }
        }) {
            ZStack {
                // Ripple effect circles
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 70, height: 70)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)

                Circle()
                    .fill(Color.red.opacity(0.5))
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.2), value: pulseAnimation)

                // Main button
                Circle()
                    .fill(Color.red)
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.red.opacity(0.5), radius: 8, x: 0, y: 4)

                Image(systemName: "mic.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            pulseAnimation = true
        }
    }

    @State private var pulseAnimation = false
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
                            .fill(Color.red)
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
                            .fill(Color.red)
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
                        if case .recording = viewModel.status {
                            Task {
                                await viewModel.stopRecording()
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


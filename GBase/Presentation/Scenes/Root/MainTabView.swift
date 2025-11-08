import SwiftUI

struct MainTabView: View {
    @Environment(\.diContainer) private var container
    @EnvironmentObject private var appState: AppState
    @StateObject private var recorderViewModel = RecorderViewModel()
    @State private var showingQuickRecorder = false

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

                ProfileView()
                    .tabItem {
                        Label(LocalizedStringKey.tabProfile.localized, systemImage: "person.circle")
                    }
                    .tag(AppState.MainTab.profile)
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
        .sheet(isPresented: $showingQuickRecorder) {
            QuickRecorderView(viewModel: recorderViewModel)
        }
        .onAppear {
            recorderViewModel.configure(container: container, shouldLoadProjects: false)
        }
    }

    private var quickRecordButton: some View {
        Button(action: {
            recorderViewModel.prepareForQuickRecording()
            showingQuickRecorder = true
            // Start recording immediately after showing the sheet
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds delay for sheet animation
                await recorderViewModel.startRecording()
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
            .navigationTitle(LocalizedStringKey.quickRecorderTitle.localized)
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


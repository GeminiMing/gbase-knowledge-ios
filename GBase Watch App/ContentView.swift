import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RecorderViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Recording status
                if viewModel.isRecording {
                    RecordingView(viewModel: viewModel)
                } else {
                    IdleView(viewModel: viewModel)
                }
            }
            .navigationTitle("GBase")
        }
        .onAppear {
            viewModel.requestMicrophonePermission()
        }
    }
}

// MARK: - Idle View (Not Recording)
struct IdleView: View {
    @ObservedObject var viewModel: RecorderViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Tap to Record")
                .font(.headline)

            Button(action: {
                Task {
                    await viewModel.startRecording()
                }
            }) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "mic.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Recording View
struct RecordingView: View {
    @ObservedObject var viewModel: RecorderViewModel

    var body: some View {
        VStack(spacing: 15) {
            // Recording indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .opacity(viewModel.isRecording ? 1.0 : 0.3)

                Text("Recording")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Duration
            Text(viewModel.formattedDuration)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            // Waveform or level indicator
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red)
                        .frame(width: 6, height: CGFloat.random(in: 20...60))
                        .animation(.easeInOut(duration: 0.3).repeatForever(), value: viewModel.isRecording)
                }
            }
            .padding(.vertical, 10)

            // Stop button
            Button(action: {
                Task {
                    await viewModel.stopRecording()
                }
            }) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                    )
            }
            .buttonStyle(.plain)

            Text("Tap to Stop")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

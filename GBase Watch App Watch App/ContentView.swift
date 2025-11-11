import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RecorderViewModel()

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(white: 0.1)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                if viewModel.isRecording {
                    RecordingView(viewModel: viewModel)
                } else {
                    IdleView(viewModel: viewModel)
                }
            }

            // Save confirmation toast
            if viewModel.showSaveConfirmation {
                VStack {
                    Spacer()
                    Text(viewModel.saveConfirmationMessage)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.9))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showSaveConfirmation)
            }
        }
        .onAppear {
            viewModel.requestMicrophonePermission()
        }
        .gesture(
            // Double-tap gesture to toggle recording
            TapGesture(count: 2)
                .onEnded { _ in
                    Task {
                        if viewModel.isRecording {
                            await viewModel.stopRecording()
                        } else {
                            await viewModel.startRecording()
                        }
                    }
                }
        )
    }
}

// MARK: - Idle View (Not Recording)
struct IdleView: View {
    @ObservedObject var viewModel: RecorderViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App name
            Text("GBase")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))

            // Record button
            Button(action: {
                Task {
                    await viewModel.startRecording()
                }
            }) {
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .opacity(pulseAnimation ? 0 : 1)
                        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: pulseAnimation)

                    // Main button
                    Circle()
                        .fill(Color.red)
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.red.opacity(0.4), radius: 12, x: 0, y: 4)

                    // Microphone icon
                    Image(systemName: "mic.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .handGestureShortcut(.primaryAction)

            // Hint text
            Text(NSLocalizedString("watch.tap_to_record", comment: ""))
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            Spacer()
        }
        .onAppear {
            pulseAnimation = true
        }
    }

    @State private var pulseAnimation = false
}

// MARK: - Recording View
struct RecordingView: View {
    @ObservedObject var viewModel: RecorderViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Recording indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .opacity(blinkAnimation ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: blinkAnimation)

                Text(NSLocalizedString("watch.rec_indicator", comment: ""))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.red)
            }
            .onAppear {
                blinkAnimation = true
            }

            // Duration
            Text(viewModel.formattedDuration)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()

            // Waveform visualization
            HStack(spacing: 3) {
                ForEach(0..<8) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red.opacity(0.8))
                        .frame(width: 4, height: barHeight(for: index))
                        .animation(
                            .easeInOut(duration: 0.3)
                            .repeatForever()
                            .delay(Double(index) * 0.1),
                            value: viewModel.isRecording
                        )
                }
            }
            .frame(height: 40)
            .padding(.vertical, 8)

            Spacer()

            // Stop button
            Button(action: {
                Task {
                    await viewModel.stopRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 64, height: 64)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                }
            }
            .buttonStyle(.plain)
            .handGestureShortcut(.primaryAction)

            // Stop hint
            Text(NSLocalizedString("watch.tap_to_stop", comment: ""))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.5))

            Spacer()
        }
        .padding()
    }

    @State private var blinkAnimation = false

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [12, 24, 36, 32, 28, 36, 20, 16]
        return viewModel.isRecording ? heights[index] : 8
    }
}

#Preview {
    ContentView()
}

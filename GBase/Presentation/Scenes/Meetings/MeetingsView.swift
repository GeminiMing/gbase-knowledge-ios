import SwiftUI

struct MeetingsView: View {
    @Environment(\.diContainer) private var container
    @StateObject private var viewModel = MeetingsViewModel()

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(viewModel.meetings.enumerated()), id: \.element.id) { index, meeting in
                    NavigationLink(destination: MeetingDetailView(meetingId: meeting.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meeting.title)
                                .font(.headline)
                            Text(meeting.meetingTime, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack {
                                Text(meeting.status.rawValue)
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(4)
                                Spacer()
                                if meeting.hasRecording {
                                    Label("录音", systemImage: "waveform")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .onAppear {
                            if index == viewModel.meetings.count - 1 {
                                Task { await viewModel.loadMore() }
                            }
                        }
                    }
                }
            }
            .navigationTitle("会议列表")
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.isLoading && viewModel.meetings.isEmpty {
                    ProgressView()
                }
            }
            .alert(isPresented: Binding<Bool>(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Alert(title: Text("错误"),
                      message: Text(viewModel.errorMessage ?? "未知错误"),
                      dismissButton: .default(Text("确定")))
            }
        }
        .onAppear {
            viewModel.configure(container: container)
            Task { await viewModel.refresh() }
        }
    }
}

#Preview {
    MeetingsView()
        .environment(\.diContainer, .preview)
}


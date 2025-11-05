import SwiftUI

struct MeetingDetailView: View {
    @Environment(\.diContainer) private var container
    @StateObject private var viewModel: MeetingDetailViewModel

    init(meetingId: String) {
        _viewModel = StateObject(wrappedValue: MeetingDetailViewModel(meetingId: meetingId))
    }

    var body: some View {
        ScrollView {
            if let detail = viewModel.detail {
                VStack(alignment: .leading, spacing: 16) {
                    Text(detail.meeting.title)
                        .font(.title2)
                        .bold()

                    if let description = detail.meeting.description {
                        Text(description)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("录音文件")
                            .font(.headline)

                        ForEach(detail.recordings) { recording in
                            VStack(alignment: .leading) {
                                Text(recording.fileName)
                                Text("时长: \(Int(recording.duration)) 秒")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("参会人员")
                            .font(.headline)
                        ForEach(detail.participants) { participant in
                            Text(participant.name)
                        }
                    }
                }
                .padding()
            } else if viewModel.isLoading {
                ProgressView("加载中...")
                    .padding()
            } else if let message = viewModel.errorMessage {
                Text(message)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle("会议详情")
        .onAppear {
            viewModel.configure(container: container)
            Task { await viewModel.load() }
        }
    }
}

#Preview {
    MeetingDetailView(meetingId: "preview")
        .environment(\.diContainer, .preview)
}


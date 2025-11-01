import Foundation
import Combine

@MainActor
final class MeetingDetailViewModel: ObservableObject {
    @Published var detail: MeetingDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let meetingId: String
    private var container: DIContainer?

    init(meetingId: String) {
        self.meetingId = meetingId
    }

    func configure(container: DIContainer) {
        self.container = container
    }

    func load() async {
        guard let container else {
            errorMessage = "依赖未注入"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await container.fetchMeetingDetailUseCase.execute(meetingId: meetingId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


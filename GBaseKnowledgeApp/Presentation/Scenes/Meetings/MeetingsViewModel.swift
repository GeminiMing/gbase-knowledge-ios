import Foundation
import Combine

@MainActor
final class MeetingsViewModel: ObservableObject {
    @Published var meetings: [Meeting] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedProjectId: String? = nil

    private var container: DIContainer?
    private var page = 1
    private let pageSize = 20
    private var hasMore = true

    func configure(container: DIContainer) {
        self.container = container
    }

    func refresh() async {
        page = 1
        hasMore = true
        meetings.removeAll()
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        guard let container else {
            errorMessage = "依赖未注入"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await container.fetchMyMeetingsUseCase.execute(page: page,
                                                                              pageSize: pageSize,
                                                                              orderBys: ["ID_DESC"],
                                                                              projectId: selectedProjectId,
                                                                              titleLike: nil)
            if page == 1 {
                meetings = response.meetings
            } else {
                meetings.append(contentsOf: response.meetings)
            }

            hasMore = meetings.count < response.totalItems
            page += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


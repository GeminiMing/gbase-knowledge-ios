import Foundation
import Combine

@MainActor
final class ProjectsViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var filteredProjects: [Project] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var searchText: String = "" {
        didSet {
            filterProjects()
        }
    }
    @Published var searchType: String = "MY_MODIFIABLE" {
        didSet {
            Task { await refresh() }
        }
    }

    private var container: DIContainer?
    private var currentPage: Int = 1
    private let pageSize: Int = 20
    private var hasMore: Bool = true
    private let allowedRoles: Set<ProjectRole> = [.owner, .contributor, .sharee]

    init(container: DIContainer? = nil) {
        self.container = container
    }

    func configure(container: DIContainer) {
        self.container = container
    }

    func refresh() async {
        currentPage = 1
        hasMore = true
        projects.removeAll()
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }

        guard let container else {
            errorMessage = "依赖未注入"
            return
        }

        do {
            let response = try await container.fetchProjectsUseCase.execute(page: currentPage,
                                                                            pageSize: pageSize,
                                                                            searchType: searchType,
                                                                            title: searchText.isEmpty ? "" : searchText)
            let filtered = response.projects.filter { allowedRoles.contains($0.myRole) }

            if currentPage == 1 {
                projects = filtered
            } else {
                projects.append(contentsOf: filtered)
            }

            let fetchedTotal = (currentPage - 1) * pageSize + response.projects.count
            hasMore = fetchedTotal < response.totalItems
            currentPage += 1
            
            filterProjects()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func filterProjects() {
        if searchText.isEmpty {
            filteredProjects = projects
        } else {
            let lowercasedSearch = searchText.lowercased()
            filteredProjects = projects.filter { project in
                project.title.lowercased().contains(lowercasedSearch) ||
                project.description.lowercased().contains(lowercasedSearch)
            }
        }
    }
}


import Foundation

public protocol FetchProjectsUseCase {
    func execute(page: Int,
                 pageSize: Int,
                 searchType: String,
                 title: String) async throws -> PagedProjects
}

public protocol FetchEditableProjectsUseCase {
    func execute() async throws -> [String: String]
}

public final class DefaultFetchProjectsUseCase: FetchProjectsUseCase {
    private let repository: ProjectRepository

    public init(repository: ProjectRepository) {
        self.repository = repository
    }

    public func execute(page: Int,
                        pageSize: Int,
                        searchType: String,
                        title: String) async throws -> PagedProjects {
        try await repository.fetchProjects(currentPage: page,
                                           pageSize: pageSize,
                                           searchType: searchType,
                                           title: title)
    }
}

public final class DefaultFetchEditableProjectsUseCase: FetchEditableProjectsUseCase {
    private let repository: ProjectRepository

    public init(repository: ProjectRepository) {
        self.repository = repository
    }

    public func execute() async throws -> [String: String] {
        try await repository.fetchEditableProjects()
    }
}


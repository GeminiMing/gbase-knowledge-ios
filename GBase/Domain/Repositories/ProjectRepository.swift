import Foundation

public protocol ProjectRepository {
    func fetchProjects(currentPage: Int, pageSize: Int, searchType: String, title: String) async throws -> PagedProjects
    func fetchEditableProjects() async throws -> [String: String]
}

public struct PagedProjects: Codable {
    public let projects: [Project]
    public let countsBySearchType: [String: Int]
    public let totalItems: Int

    public init(projects: [Project], countsBySearchType: [String: Int], totalItems: Int) {
        self.projects = projects
        self.countsBySearchType = countsBySearchType
        self.totalItems = totalItems
    }
}


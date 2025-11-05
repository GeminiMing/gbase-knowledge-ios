import Foundation

public final class RemoteProjectRepository: ProjectRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func fetchProjects(currentPage: Int,
                              pageSize: Int,
                              searchType: String,
                              title: String) async throws -> PagedProjects {
        let request = ProjectSearchRequestDTO(currentPage: currentPage,
                                              pageSize: pageSize,
                                              orderBys: ["ID_DESC"],
                                              searchType: searchType,
                                              title: title)

        let response = try await client.send(Endpoint(path: "/project/my/search/page", method: .post),
                                             body: request,
                                             responseType: ProjectSearchResponseDTO.self)

        guard response.success, let data = response.data else {
            let message = response.fieldErrors?.first?.message ?? "获取项目列表失败"
            throw APIError.serverError(statusCode: 422, message: message)
        }

        let projects = data.projects.map(ProjectMapper.map)
        let paginator = data.paginator
        let totalItems = paginator.totalItems ?? paginator.items ?? projects.count

        return PagedProjects(projects: projects,
                             countsBySearchType: data.eachSearchTypeCountMap,
                             totalItems: totalItems)
    }

    public func fetchEditableProjects() async throws -> [String: String] {
        let response = try await client.send(Endpoint(path: "/project/myModifiableProject/idAndTitleMap/get", method: .get),
                                             responseType: EditableProjectResponseDTO.self)

        guard response.success, let data = response.data else {
            let message = response.fieldErrors?.first?.message ?? "获取可编辑项目失败"
            throw APIError.serverError(statusCode: 422, message: message)
        }

        return data.projectIdAndTitleMap
    }
}


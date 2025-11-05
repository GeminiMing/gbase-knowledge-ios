import Foundation

struct ProjectSearchRequestDTO: Encodable {
    let currentPage: Int
    let pageSize: Int
    let orderBys: [String]
    let searchType: String
    let title: String
}

struct ProjectSearchResponseDTO: Decodable {
    let success: Bool
    let fieldErrors: [APIFieldErrorDTO]?
    let data: ProjectSearchDataDTO?
}

struct ProjectSearchDataDTO: Decodable {
    let eachSearchTypeCountMap: [String: Int]
    let projects: [ProjectDTO]
    let paginator: PaginatorDTO
}

struct ProjectDTO: Decodable {
    let id: String
    let title: String
    let description: String?
    let itemCount: Int
    let updatedAt: Date
    let createdAt: Date
    let myRole: String
}

struct EditableProjectResponseDTO: Decodable {
    let success: Bool
    let fieldErrors: [APIFieldErrorDTO]?
    let data: EditableProjectDataDTO?
}

struct EditableProjectDataDTO: Decodable {
    let projectIdAndTitleMap: [String: String]
}

struct PaginatorDTO: Decodable {
    let currentPage: Int?
    let items: Int?
    let pageSize: Int?
    let totalPages: Int?
    let totalItems: Int?
    let pages: Int?
}


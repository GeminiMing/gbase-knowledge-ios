import Foundation

public enum ProjectRole: String, Codable, CaseIterable {
    case owner = "OWNER"
    case contributor = "CONTRIBUTOR"
    case sharee = "SHAREE"
}

public struct Project: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let description: String
    public let itemCount: Int
    public let myRole: ProjectRole
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: String,
                title: String,
                description: String,
                itemCount: Int,
                myRole: ProjectRole,
                createdAt: Date,
                updatedAt: Date) {
        self.id = id
        self.title = title
        self.description = description
        self.itemCount = itemCount
        self.myRole = myRole
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}


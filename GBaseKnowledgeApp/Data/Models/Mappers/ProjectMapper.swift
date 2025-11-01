import Foundation

struct ProjectMapper {
    static func map(_ dto: ProjectDTO) -> Project {
        Project(id: dto.id,
                title: dto.title,
                description: dto.description ?? "",
                itemCount: dto.itemCount,
                myRole: ProjectRole(rawValue: dto.myRole) ?? .sharee,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt)
    }
}


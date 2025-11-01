import Foundation

public protocol CreateMeetingUseCase {
    func execute(projectId: String,
                 title: String,
                 meetingTime: Date,
                 location: String?,
                 description: String?) async throws -> Meeting
}

public protocol FetchMyMeetingsUseCase {
    func execute(page: Int,
                 pageSize: Int,
                 orderBys: [String],
                 projectId: String?,
                 titleLike: String?) async throws -> PagedMeetings
}

public protocol FetchProjectMeetingsUseCase {
    func execute(projectId: String,
                 page: Int,
                 pageSize: Int) async throws -> PagedMeetings
}

public protocol FetchMeetingDetailUseCase {
    func execute(meetingId: String) async throws -> MeetingDetail
}

public final class DefaultCreateMeetingUseCase: CreateMeetingUseCase {
    private let repository: MeetingRepository

    public init(repository: MeetingRepository) {
        self.repository = repository
    }

    public func execute(projectId: String,
                        title: String,
                        meetingTime: Date,
                        location: String?,
                        description: String?) async throws -> Meeting {
        try await repository.createMeeting(projectId: projectId,
                                            title: title,
                                            meetingTime: meetingTime,
                                            location: location,
                                            description: description)
    }
}

public final class DefaultFetchMyMeetingsUseCase: FetchMyMeetingsUseCase {
    private let repository: MeetingRepository

    public init(repository: MeetingRepository) {
        self.repository = repository
    }

    public func execute(page: Int,
                        pageSize: Int,
                        orderBys: [String],
                        projectId: String?,
                        titleLike: String?) async throws -> PagedMeetings {
        try await repository.fetchMyMeetings(page: page,
                                             pageSize: pageSize,
                                             orderBys: orderBys,
                                             projectId: projectId,
                                             titleLike: titleLike)
    }
}

public final class DefaultFetchProjectMeetingsUseCase: FetchProjectMeetingsUseCase {
    private let repository: MeetingRepository

    public init(repository: MeetingRepository) {
        self.repository = repository
    }

    public func execute(projectId: String,
                        page: Int,
                        pageSize: Int) async throws -> PagedMeetings {
        try await repository.fetchProjectMeetings(projectId: projectId,
                                                  page: page,
                                                  pageSize: pageSize)
    }
}

public final class DefaultFetchMeetingDetailUseCase: FetchMeetingDetailUseCase {
    private let repository: MeetingRepository

    public init(repository: MeetingRepository) {
        self.repository = repository
    }

    public func execute(meetingId: String) async throws -> MeetingDetail {
        try await repository.fetchMeetingDetail(meetingId: meetingId)
    }
}


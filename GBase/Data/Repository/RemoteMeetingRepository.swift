import Foundation

public final class RemoteMeetingRepository: MeetingRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func createMeeting(projectId: String,
                              title: String,
                              meetingTime: Date,
                              location: String?,
                              description: String?) async throws -> Meeting {
        let request = CreateMeetingRequestDTO(projectId: projectId,
                                              title: title,
                                              meetingTime: meetingTime,
                                              location: location,
                                              description: description)

        let response = try await client.send(Endpoint(path: "/meeting/create", method: .post),
                                             body: request,
                                             responseType: CreateMeetingResponseDTO.self)

        guard response.success, let data = response.data else {
            let message = response.fieldErrors?.first?.message
                ?? response.error?.message
                ?? "创建会议失败"
            throw APIError.serverError(statusCode: 422, message: message)
        }

        let bindRequest = ProjectItemSetRequestDTO(projectId: projectId,
                                                   itemId: data.id,
                                                   itemType: "MEETING")

        let bindResponse = try await client.send(Endpoint(path: "/project/item/set", method: .post),
                                                 body: bindRequest,
                                                 responseType: ProjectItemSetResponseDTO.self)

        guard bindResponse.success else {
            let message = bindResponse.fieldErrors?.first?.message ?? "会议绑定项目失败"
            throw APIError.serverError(statusCode: 422, message: message)
        }

        let now = Date()
        return Meeting(id: data.id,
                       projectId: projectId,
                       title: title,
                       description: description,
                       meetingTime: meetingTime,
                       location: location,
                       duration: nil,
                       status: .pending,
                       hasRecording: false,
                       hasTranscript: false,
                       hasSummary: false,
                       createdAt: now,
                       updatedAt: now)
    }

    public func fetchMyMeetings(page: Int,
                                pageSize: Int,
                                orderBys: [String],
                                projectId: String?,
                                titleLike: String?) async throws -> PagedMeetings {
        let request = MeetingSearchRequestDTO(currentPage: page,
                                              pageSize: pageSize,
                                              orderBys: orderBys,
                                              projectId: projectId ?? "0",
                                              titleLike: titleLike ?? "")

        let response = try await client.send(Endpoint(path: "/meeting/MyMeetings/searchPage", method: .post),
                                             body: request,
                                             responseType: MeetingSearchResponseDTO.self)

        guard response.success else {
            throw APIError.serverError(statusCode: 422, message: "获取会议列表失败")
        }

        let meetings = response.meetings.map(MeetingMapper.map)
        let paginator = response.paginator
        return PagedMeetings(meetings: meetings,
                             currentPage: paginator.currentPage ?? page,
                             pageSize: paginator.pageSize ?? pageSize,
                             totalPages: paginator.totalPages ?? 1,
                             totalItems: paginator.totalItems ?? meetings.count)
    }

    public func fetchProjectMeetings(projectId: String,
                                     page: Int,
                                     pageSize: Int) async throws -> PagedMeetings {
        let request = MeetingSearchRequestDTO(currentPage: page,
                                              pageSize: pageSize,
                                              orderBys: ["ID_DESC"],
                                              projectId: projectId,
                                              titleLike: "")

        let response = try await client.send(Endpoint(path: "/meeting/projectMeetings/searchPage", method: .post),
                                             body: request,
                                             responseType: MeetingSearchResponseDTO.self)

        guard response.success else {
            throw APIError.serverError(statusCode: 422, message: "获取项目会议失败")
        }

        let meetings = response.meetings.map(MeetingMapper.map)
        let paginator = response.paginator
        return PagedMeetings(meetings: meetings,
                             currentPage: paginator.currentPage ?? page,
                             pageSize: paginator.pageSize ?? pageSize,
                             totalPages: paginator.totalPages ?? 1,
                             totalItems: paginator.totalItems ?? meetings.count)
    }

    public func fetchMeetingDetail(meetingId: String) async throws -> MeetingDetail {
        let response = try await client.send(Endpoint(path: "/meeting/query/getById/\(meetingId)", method: .get),
                                             responseType: MeetingDetailResponseDTO.self)

        guard response.success else {
            throw APIError.serverError(statusCode: 422, message: "获取会议详情失败")
        }

        let meeting = MeetingMapper.map(response.meeting)
        let recordings = response.recordings.map { RecordingMapper.map($0, meetingId: meeting.id, projectId: meeting.projectId) }
        let participants = response.participants.map(MeetingMapper.mapParticipant)
        return MeetingDetail(meeting: meeting, recordings: recordings, participants: participants)
    }
}


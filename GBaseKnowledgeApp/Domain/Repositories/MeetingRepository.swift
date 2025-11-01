import Foundation

public protocol MeetingRepository {
    func createMeeting(projectId: String,
                       title: String,
                       meetingTime: Date,
                       location: String?,
                       description: String?) async throws -> Meeting

    func fetchMyMeetings(page: Int,
                         pageSize: Int,
                         orderBys: [String],
                         projectId: String?,
                         titleLike: String?) async throws -> PagedMeetings

    func fetchProjectMeetings(projectId: String,
                              page: Int,
                              pageSize: Int) async throws -> PagedMeetings

    func fetchMeetingDetail(meetingId: String) async throws -> MeetingDetail
}

public struct PagedMeetings: Codable {
    public let meetings: [Meeting]
    public let currentPage: Int
    public let pageSize: Int
    public let totalPages: Int
    public let totalItems: Int

    public init(meetings: [Meeting],
                currentPage: Int,
                pageSize: Int,
                totalPages: Int,
                totalItems: Int) {
        self.meetings = meetings
        self.currentPage = currentPage
        self.pageSize = pageSize
        self.totalPages = totalPages
        self.totalItems = totalItems
    }
}

public struct MeetingDetail: Codable {
    public let meeting: Meeting
    public let recordings: [Recording]
    public let participants: [MeetingParticipant]

    public init(meeting: Meeting,
                recordings: [Recording],
                participants: [MeetingParticipant]) {
        self.meeting = meeting
        self.recordings = recordings
        self.participants = participants
    }
}


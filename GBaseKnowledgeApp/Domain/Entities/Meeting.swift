import Foundation

public enum MeetingStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
}

public struct Meeting: Identifiable, Codable, Equatable {
    public let id: String
    public let projectId: String
    public let title: String
    public let description: String?
    public let meetingTime: Date
    public let location: String?
    public let duration: Int?
    public let status: MeetingStatus
    public let hasRecording: Bool
    public let hasTranscript: Bool
    public let hasSummary: Bool
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: String,
                projectId: String,
                title: String,
                description: String?,
                meetingTime: Date,
                location: String?,
                duration: Int?,
                status: MeetingStatus,
                hasRecording: Bool,
                hasTranscript: Bool,
                hasSummary: Bool,
                createdAt: Date,
                updatedAt: Date) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.description = description
        self.meetingTime = meetingTime
        self.location = location
        self.duration = duration
        self.status = status
        self.hasRecording = hasRecording
        self.hasTranscript = hasTranscript
        self.hasSummary = hasSummary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct MeetingParticipant: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let userId: String?
    public let type: String

    public init(id: String, name: String, userId: String?, type: String) {
        self.id = id
        self.name = name
        self.userId = userId
        self.type = type
    }
}


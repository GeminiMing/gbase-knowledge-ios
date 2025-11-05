import Foundation

struct MeetingMapper {
    static func map(_ dto: MeetingDTO) -> Meeting {
        Meeting(id: dto.id,
                projectId: dto.projectId,
                title: dto.title,
                description: dto.description,
                meetingTime: dto.meetingTime,
                location: dto.location,
                duration: dto.duration,
                status: MeetingStatus(rawValue: dto.status) ?? .pending,
                hasRecording: dto.hasRecording ?? false,
                hasTranscript: dto.hasTranscript ?? false,
                hasSummary: dto.hasSummary ?? false,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt)
    }

    static func mapParticipant(_ dto: MeetingParticipantDTO) -> MeetingParticipant {
        MeetingParticipant(id: dto.id,
                           name: dto.name,
                           userId: dto.userId,
                           type: dto.type)
    }
}


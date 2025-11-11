import Foundation

struct CreateMeetingRequestDTO: Encodable {
    let projectId: String
    let title: String
    let meetingTime: Date
    let location: String?
    let description: String?

    private enum CodingKeys: String, CodingKey {
        case projectId
        case title
        case meetingTime
        case actualStartAt
        case location
        case description
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(title, forKey: .title)

        let formatted = DateFormatter.yyyyMMddHHmmss.string(from: meetingTime)
        try container.encode(formatted, forKey: .meetingTime)
        try container.encode(formatted, forKey: .actualStartAt)

        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(description, forKey: .description)
    }
}

struct CreateMeetingResponseDTO: Decodable {
    let success: Bool
    let fieldErrors: [APIFieldErrorDTO]?
    let data: CreateMeetingDataDTO?
    let error: APIResponseErrorDTO?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Default success to false if not present
        success = (try? container.decode(Bool.self, forKey: .success)) ?? false
        fieldErrors = try? container.decode([APIFieldErrorDTO].self, forKey: .fieldErrors)
        data = try? container.decode(CreateMeetingDataDTO.self, forKey: .data)
        error = try? container.decode(APIResponseErrorDTO.self, forKey: .error)
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case fieldErrors
        case data
        case error
    }
}

struct CreateMeetingDataDTO: Decodable {
    let id: String
    let uuid: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case uuid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = ""
        }
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid)
    }
}

struct APIResponseErrorDTO: Decodable {
    let name: String?
    let message: String?
}

struct MeetingSearchRequestDTO: Encodable {
    let currentPage: Int
    let pageSize: Int
    let orderBys: [String]
    let projectId: String
    let titleLike: String
}

struct MeetingSearchResponseDTO: Decodable {
    let success: Bool
    let meetings: [MeetingDTO]
    let paginator: PaginatorDTO
}

struct MeetingDTO: Decodable {
    let id: String
    let projectId: String
    let title: String
    let description: String?
    let meetingTime: Date
    let location: String?
    let duration: Int?
    let status: String
    let hasRecording: Bool?
    let hasTranscript: Bool?
    let hasSummary: Bool?
    let createdAt: Date
    let updatedAt: Date
}

struct MeetingDetailResponseDTO: Decodable {
    let success: Bool
    let meeting: MeetingDTO
    let recordings: [RecordingDTO]
    let participants: [MeetingParticipantDTO]
}

struct MeetingParticipantDTO: Decodable {
    let id: String
    let name: String
    let userId: String?
    let type: String
}

struct ProjectItemSetRequestDTO: Encodable {
    let projectId: String
    let itemId: String
    let itemType: String
}

struct ProjectItemSetResponseDTO: Decodable {
    let success: Bool
    let fieldErrors: [APIFieldErrorDTO]?
    let data: ProjectItemSetDataDTO?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Default success to false if not present
        success = (try? container.decode(Bool.self, forKey: .success)) ?? false
        fieldErrors = try? container.decode([APIFieldErrorDTO].self, forKey: .fieldErrors)
        data = try? container.decode(ProjectItemSetDataDTO.self, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case fieldErrors
        case data
    }
}

struct ProjectItemSetDataDTO: Decodable {
    let id: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
    }
}


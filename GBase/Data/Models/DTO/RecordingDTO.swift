import Foundation

struct RecordingDTO: Decodable {
    let id: String
    let fileName: String
    let fileSize: Int64
    let duration: Double
    let url: URL?
    let contentHash: String?
    let uploadStatus: String?
    let uploadProgress: Double?
    let uploadId: Int?
    let createdAt: Date?
    let actualStartAt: Date?
    let actualEndAt: Date?
}

struct UploadApplyRequestDTO: Encodable {
    let meetingId: String
    let name: String
    let extensionName: String
    let contentHash: String
    let length: Int64
    let fileType: String
    let fromType: String
    let actualStartAt: String
    let actualEndAt: String

    enum CodingKeys: String, CodingKey {
        case meetingId
        case name
        case extensionName = "extension"
        case contentHash
        case length
        case fileType
        case fromType
        case actualStartAt
        case actualEndAt
    }
}

struct UploadApplyResponseDTO: Decodable {
    let success: Bool
    let fieldErrors: [APIFieldErrorDTO]?
    let data: UploadApplyDataDTO?
    let error: APIResponseErrorDTO?
}

struct UploadApplyDataDTO: Decodable {
    let id: String
    let uploadUri: URL?
    let uuid: String?
    let name: String?
    let contentType: String?
    let meetingId: String?

    enum CodingKeys: String, CodingKey {
        case id, uploadUri, uuid, name, contentType, meetingId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle id as String or Int (for error responses with id: 0)
        if let idString = try? container.decode(String.self, forKey: .id) {
            self.id = idString
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            self.id = String(idInt)
        } else {
            // For error cases, use "0" as fallback
            self.id = "0"
        }

        self.uploadUri = try? container.decode(URL.self, forKey: .uploadUri)
        self.uuid = try? container.decode(String.self, forKey: .uuid)
        self.name = try? container.decode(String.self, forKey: .name)
        self.contentType = try? container.decode(String.self, forKey: .contentType)

        // Handle meetingId as String or Int (for error responses with meetingId: 0)
        if let meetingIdString = try? container.decode(String.self, forKey: .meetingId) {
            self.meetingId = meetingIdString
        } else if let meetingIdInt = try? container.decode(Int.self, forKey: .meetingId) {
            self.meetingId = String(meetingIdInt)
        } else {
            self.meetingId = nil
        }
    }
}

struct UploadFinishRequestDTO: Encodable {
    let id: Int
    let contentHash: String
}

struct GenericResponseDTO: Decodable {
    let success: Bool
    let message: String?
}

struct FileUploadRequestDTO {
    let meetingId: Int
    let name: String
    let `extension`: String
    let file: Data
    let fileType: String
    let fromType: String
    let fromId: String?
    let actualStartAt: String
    let actualEndAt: String
}

struct FileUploadResponseDTO: Decodable {
    let success: Bool
    let fieldErrors: [APIFieldErrorDTO]?
    let data: FileUploadDataDTO?
    let error: APIResponseErrorDTO?
}

struct FileUploadDataDTO: Decodable {
    let id: String?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case id, message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle id as String or Int
        if let idString = try? container.decode(String.self, forKey: .id) {
            self.id = idString
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            self.id = String(idInt)
        } else {
            self.id = nil
        }
        
        self.message = try? container.decode(String.self, forKey: .message)
    }
}


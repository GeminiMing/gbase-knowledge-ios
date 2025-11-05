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
    let uploadUri: URL
    let uuid: String?
    let name: String?
    let contentType: String
    let meetingId: String?
}

struct UploadFinishRequestDTO: Encodable {
    let id: Int
    let contentHash: String
}

struct GenericResponseDTO: Decodable {
    let success: Bool
    let message: String?
}


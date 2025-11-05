import Foundation

public final class FileStorageService {
    private let fileManager: FileManager
    private let recordingsDirectoryName = "Recordings"
    private let recordingFileExtension = "wav"

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func recordingsDirectory() throws -> URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsURL = documents.appendingPathComponent(recordingsDirectoryName)

        if !fileManager.fileExists(atPath: recordingsURL.path) {
            try fileManager.createDirectory(at: recordingsURL, withIntermediateDirectories: true)
        }

        return recordingsURL
    }

    public func makeRecordingURL(timestamp: Date, meetingId: String) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "recording_\(formatter.string(from: timestamp))_\(meetingId).\(recordingFileExtension)"
        return try recordingsDirectory().appendingPathComponent(fileName)
    }

    public func fileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }

    public func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return CryptoHelper.sha256(data: data)
    }

    public func removeFile(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}


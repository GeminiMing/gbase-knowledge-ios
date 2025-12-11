import Foundation

public final class FileStorageService {
    private let fileManager: FileManager
    private let recordingsDirectoryName = "Recordings"
    private let recordingFileExtension = "m4a"

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

    // MARK: - Watch Recording Support

    /// Normalize file name to ensure it only contains safe ASCII characters
    /// This prevents issues with file systems that don't support non-ASCII characters well
    private func normalizeFileName(_ fileName: String) -> String {
        // Remove any path separators that might cause issues
        var normalized = fileName.replacingOccurrences(of: "/", with: "_")
        normalized = normalized.replacingOccurrences(of: "\\", with: "_")
        
        // Ensure only ASCII characters are used (remove any non-ASCII characters)
        // This is important for cross-platform compatibility and Watch connectivity
        // Allowed characters: a-z, A-Z, 0-9, period, underscore, hyphen
        let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        
        // Filter out any characters not in the allowed set
        normalized = String(normalized.unicodeScalars.filter { allowedCharacterSet.contains($0) })
        
        // Ensure the filename is not empty
        if normalized.isEmpty {
            normalized = "recording_\(UUID().uuidString.prefix(8))"
        }
        
        return normalized
    }

    /// Save a recording file from Watch to the app's recordings directory
    public func saveRecordingFile(from sourceURL: URL, fileName: String) throws -> URL {
        let baseDirectory = try recordingsDirectory()
        
        // Normalize the file name to ensure it's safe (ASCII only, no path separators)
        let normalizedFileName = normalizeFileName(fileName)
        var destinationURL = baseDirectory.appendingPathComponent(normalizedFileName)
        
        // If file already exists, generate a unique name to avoid overwriting
        if fileManager.fileExists(atPath: destinationURL.path) {
            let nameWithoutExtension = (normalizedFileName as NSString).deletingPathExtension
            let fileExtension = (normalizedFileName as NSString).pathExtension
            var counter = 1
            repeat {
                let newFileName = "\(nameWithoutExtension)_\(counter).\(fileExtension)"
                destinationURL = baseDirectory.appendingPathComponent(newFileName)
                counter += 1
            } while fileManager.fileExists(atPath: destinationURL.path) && counter < 1000
            
            // If still exists after 1000 attempts, add UUID to ensure uniqueness
            if fileManager.fileExists(atPath: destinationURL.path) {
                let uniqueFileName = "\(nameWithoutExtension)_\(UUID().uuidString.prefix(8)).\(fileExtension)"
                destinationURL = baseDirectory.appendingPathComponent(uniqueFileName)
            }
        }

        // Copy file to recordings directory
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        return destinationURL
    }
}


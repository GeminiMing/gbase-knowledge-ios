import Foundation
import CryptoKit

struct CryptoHelper {
    static func sha256(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}


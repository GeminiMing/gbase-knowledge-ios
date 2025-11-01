import Foundation

struct Logger {
    static func debug(_ message: String) {
        #if DEBUG
        print("[DEBUG] \(message)")
        #endif
    }

    static func error(_ message: String) {
        #if DEBUG
        print("[ERROR] \(message)")
        #endif
    }
}


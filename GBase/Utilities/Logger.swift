import Foundation
import os.log

struct Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sparticle.gbase"
    private static let logger = OSLog(subsystem: subsystem, category: "App")
    
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        #if DEBUG
        print("🔵 [DEBUG] \(logMessage)")
        #endif
        
        os_log("%{public}@", log: logger, type: .debug, logMessage)
    }

    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        #if DEBUG
        print("ℹ️ [INFO] \(logMessage)")
        #endif
        
        os_log("%{public}@", log: logger, type: .info, logMessage)
    }

    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        // 在 Release 版本中也输出错误日志，方便 TestFlight 调试
        print("❌ [ERROR] \(logMessage)")
        os_log("%{public}@", log: logger, type: .error, logMessage)
    }
    
    static func fatal(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        // 致命错误始终输出，包括 Release 版本
        print("💥 [FATAL] \(logMessage)")
        os_log("%{public}@", log: logger, type: .fault, logMessage)
    }
}


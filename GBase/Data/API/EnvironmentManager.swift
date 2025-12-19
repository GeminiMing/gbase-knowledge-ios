import Foundation
import Combine

/// 环境管理器，用于动态切换 API 环境
public class EnvironmentManager: ObservableObject {
    public static let shared = EnvironmentManager()
    
    private let environmentKey = "com.gbase.api.environment"
    
    @Published public private(set) var currentEnvironment: APIConfiguration.Environment
    
    private init() {
        // 从 UserDefaults 读取保存的环境，如果没有则使用 production
        if let savedEnvironmentString = UserDefaults.standard.string(forKey: environmentKey),
           let savedEnvironment = APIConfiguration.Environment(rawValue: savedEnvironmentString) {
            self.currentEnvironment = savedEnvironment
        } else {
            self.currentEnvironment = .production
        }
    }
    
    /// 切换环境
    public func switchEnvironment(_ environment: APIConfiguration.Environment) {
        currentEnvironment = environment
        UserDefaults.standard.set(environment.rawValue, forKey: environmentKey)
        print("🔄 环境已切换到: \(environment.displayName)")
    }
    
    /// 获取所有可用环境
    public var availableEnvironments: [APIConfiguration.Environment] {
        return [.production, .development]
    }
}


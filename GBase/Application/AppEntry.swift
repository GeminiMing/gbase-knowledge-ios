import SwiftUI
import Darwin

@main
struct GBaseKnowledgeApp: App {
    @State private var container: DIContainer = .bootstrap()

    init() {
        // 设置全局异常处理
        setupExceptionHandling()
        
        RealmConfigurator.configure()
    }
    
    private func setupExceptionHandling() {
        // 捕获未捕获的异常
        NSSetUncaughtExceptionHandler { exception in
            Logger.fatal("未捕获的异常: \(exception.name.rawValue)")
            Logger.fatal("原因: \(exception.reason ?? "未知")")
            Logger.fatal("调用栈: \(exception.callStackSymbols.joined(separator: "\n"))")
        }
        
        // 捕获信号错误（如 EXC_BAD_ACCESS）
        signal(SIGABRT) { _ in
            Logger.fatal("收到 SIGABRT 信号")
        }
        signal(SIGILL) { _ in
            Logger.fatal("收到 SIGILL 信号")
        }
        signal(SIGSEGV) { _ in
            Logger.fatal("收到 SIGSEGV 信号")
        }
        signal(SIGFPE) { _ in
            Logger.fatal("收到 SIGFPE 信号")
        }
        signal(SIGBUS) { _ in
            Logger.fatal("收到 SIGBUS 信号")
        }
        
        Logger.info("应用启动 - 异常处理已设置")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.diContainer, container)
                .environmentObject(container.appState)
                .onAppear {
                    // Initialize WatchConnectivityService after app appears
                    // This ensures activation happens after app is fully launched
                    _ = WatchConnectivityService.shared

                    // Initialize RecorderViewModel on first appear
                    if container.appState.recorderViewModel == nil {
                        let recorderViewModel = RecorderViewModel()
                        recorderViewModel.configure(container: container, shouldLoadProjects: true)
                        container.appState.recorderViewModel = recorderViewModel
                    }
                }
        }
    }
}


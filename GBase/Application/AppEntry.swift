import SwiftUI

@main
struct GBaseKnowledgeApp: App {
    @State private var container: DIContainer = .bootstrap()

    init() {
        RealmConfigurator.configure()

        // 调试：检查本地化是否正常工作
        #if DEBUG
        debugLocalization()
        #endif
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
                    print("📱 [iPhone] WatchConnectivityService initialized")

                    // Initialize RecorderViewModel on first appear
                    if container.appState.recorderViewModel == nil {
                        let recorderViewModel = RecorderViewModel()
                        recorderViewModel.configure(container: container, shouldLoadProjects: true)
                        container.appState.recorderViewModel = recorderViewModel
                    }
                }
        }
    }
    
    #if DEBUG
    private func debugLocalization() {
        print("=== 本地化调试信息 ===")
        print("当前语言: \(Locale.preferredLanguages.joined(separator: ", "))")
        
        // 测试旧的键
        print("测试旧键 'profile.title': '\(LocalizedStringKey.profileTitle.localized)'")
        print("测试旧键 'common.ok': '\(LocalizedStringKey.commonOk.localized)'")
        
        // 测试新的键
        print("测试新键 'projects.search_placeholder': '\(LocalizedStringKey.projectsSearchPlaceholder.localized)'")
        print("测试新键 'projects.empty_title': '\(LocalizedStringKey.projectsEmptyTitle.localized)'")
        print("测试新键 'projects.search_empty_title': '\(LocalizedStringKey.projectsSearchEmptyTitle.localized)'")
        print("测试新键 'project_role.owner': '\(LocalizedStringKey.projectRoleOwner.localized)'")
        
        // 检查 Bundle 中是否有本地化文件
        let languages = ["zh-Hans", "en", "ja", "Base"]
        for lang in languages {
            let paths = [
                Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: lang),
                Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "Resources/\(lang).lproj"),
                Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "\(lang).lproj"),
            ]
            
            for path in paths.compactMap({ $0 }) {
                if let dict = NSDictionary(contentsOfFile: path) {
                    let hasNewKeys = dict.allKeys.contains { key in
                        guard let keyStr = key as? String else { return false }
                        return keyStr.contains("projects.search") || keyStr.contains("project_role")
                    }
                    if hasNewKeys {
                        print("✅ 找到 \(lang) 本地化文件: \(path)")
                        print("   包含新键: \(dict.allKeys.filter { ($0 as? String)?.contains("projects.search") == true || ($0 as? String)?.contains("project_role") == true }.count) 个")
                        break
                    }
                }
            }
        }
        
        print("====================")
    }
    #endif
}


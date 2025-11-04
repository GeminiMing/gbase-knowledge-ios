import SwiftUI

struct RootView: View {
    @Environment(\.diContainer) private var container
    @EnvironmentObject private var appState: AppState
    @State private var hasBootstrapped = false

    var body: some View {
        Group {
            switch appState.authState {
            case .loading:
                ProgressView("加载中...")
            case .unauthenticated:
                LoginView()
            case .authenticated:
                MainTabView()
            }
        }
        .task {
            guard !hasBootstrapped else { return }
            hasBootstrapped = true
            await bootstrap()
        }
    }

    private func bootstrap() async {
        print("🚀 App 启动，开始 bootstrap...")

        await MainActor.run {
            appState.markLoading()
        }

        do {
            print("🔑 尝试从 Keychain 读取已保存的 session...")
            _ = try await container.tokenStore.currentSession()
            print("✅ 找到已保存的 session，开始自动登录")

            let context = try await container.fetchCurrentUserUseCase.execute()
            await MainActor.run {
                container.appState.update(authContext: context)
            }

            print("✅ 自动登录成功，用户: \(context.user.name)")

            // 初始化公司信息
            await container.companyManager.initialize()
        } catch {
            print("⚠️ 自动登录失败: \(error.localizedDescription)")
            print("👉 显示登录页面")
            await MainActor.run {
                container.appState.markUnauthenticated()
            }
        }
    }
}

#Preview {
    RootView()
        .environment(\.diContainer, .preview)
        .environmentObject(DIContainer.preview.appState)
}


import SwiftUI

struct RootView: View {
    @Environment(\.diContainer) private var container
    @EnvironmentObject private var appState: AppState
    @State private var hasBootstrapped = false

    var body: some View {
        Group {
            switch appState.authState {
            case .loading:
                ProgressView(LocalizedStringKey.commonLoading.localized)
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
        print("🔍 [Debug] EnvironmentObject AppState ID: \(ObjectIdentifier(appState))")
        print("🔍 [Debug] Container AppState ID: \(ObjectIdentifier(container.appState))")
        print("🔍 [Debug] 两者是否相同: \(appState === container.appState)")

        await MainActor.run {
            appState.markLoading()
        }

        do {
            print("🔑 尝试从 Keychain 读取已保存的 session...")
            let session = try await container.tokenStore.currentSession()
            print("✅ 找到已保存的 session")
            print("   - Access Token: \(session.accessToken.prefix(20))...")
            print("   - Expires At: \(session.expiresAt)")

            print("🔑 开始获取用户信息...")
            let context = try await container.fetchCurrentUserUseCase.execute()

            print("✅ 用户信息获取成功: \(context.user.name) (\(context.user.email))")

            await MainActor.run {
                print("🔄 更新 AppState 为已认证状态...")
                appState.update(authContext: context)
                print("✅ AppState 更新完成，当前状态: \(appState.authState)")
            }

            print("🏢 开始初始化公司信息...")
            await container.companyManager.initialize()
            print("✅ 公司信息初始化完成")

            print("✅ 自动登录完整流程成功")
        } catch {
            print("⚠️ 自动登录失败")
            print("   错误类型: \(type(of: error))")
            print("   错误描述: \(error.localizedDescription)")
            print("   错误详情: \(error)")
            print("👉 显示登录页面")
            await MainActor.run {
                appState.markUnauthenticated()
            }
        }
    }
}

#Preview {
    RootView()
        .environment(\.diContainer, .preview)
        .environmentObject(DIContainer.preview.appState)
}


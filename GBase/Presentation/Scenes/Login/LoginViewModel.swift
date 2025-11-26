import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var rememberPassword: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var container: DIContainer?

    init(container: DIContainer? = nil) {
        self.container = container
    }

    func configure(container: DIContainer) {
        self.container = container

        // Load remember password preference
        rememberPassword = container.credentialsStore.shouldRememberCredentials()

        // Load saved credentials if remember is enabled
        Task {
            if let credentials = try? await container.credentialsStore.loadCredentials() {
                email = credentials.email
                password = credentials.password
            }
        }
    }

    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = LocalizedStringKey.loginEmptyFields.localized
            return
        }

        isLoading = true
        errorMessage = nil

        guard let container else {
            errorMessage = LocalizedStringKey.profileDependencyNotInjected.localized
            isLoading = false
            return
        }

        do {
            print("🔐 [Login] 开始登录...")
            print("   Email: \(email)")
            let context = try await container.loginUseCase.execute(email: email, password: password)
            print("✅ [Login] 登录成功")
            print("   用户: \(context.user.name)")
            print("   Token: \(context.session.accessToken.prefix(20))...")

            print("🔄 [Login] 更新 AppState...")
            container.appState.update(authContext: context)
            print("✅ [Login] AppState 更新完成，当前状态: \(container.appState.authState)")

            // Save credentials if remember password is enabled
            container.credentialsStore.setShouldRememberCredentials(rememberPassword)
            if rememberPassword {
                try? await container.credentialsStore.saveCredentials(email: email, password: password)
            } else {
                try? await container.credentialsStore.removeCredentials()
            }

            // 登录成功后初始化公司信息
            print("🏢 [Login] 初始化公司信息...")
            await container.companyManager.initialize()
            print("✅ [Login] 公司信息初始化完成")

            print("✅ [Login] 登录流程全部完成")
        } catch {
            print("❌ [Login] 登录失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}


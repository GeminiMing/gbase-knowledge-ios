import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var container: DIContainer?

    init(container: DIContainer? = nil) {
        self.container = container
    }

    func configure(container: DIContainer) {
        self.container = container
    }

    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "请输入邮箱和密码"
            return
        }

        isLoading = true
        errorMessage = nil

        guard let container else {
            errorMessage = "依赖未注入"
            isLoading = false
            return
        }

        do {
            let context = try await container.loginUseCase.execute(email: email, password: password)
            container.appState.update(authContext: context)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}


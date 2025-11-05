import Foundation
import Combine

@MainActor
final class RootViewModel: ObservableObject {
    private let appState: AppState
    private let fetchCurrentUserUseCase: FetchCurrentUserUseCase
    private let tokenStore: TokenStore

    init(appState: AppState,
         fetchCurrentUserUseCase: FetchCurrentUserUseCase,
         tokenStore: TokenStore) {
        self.appState = appState
        self.fetchCurrentUserUseCase = fetchCurrentUserUseCase
        self.tokenStore = tokenStore
    }

    func bootstrap() async {
        appState.markLoading()
        do {
            _ = try await tokenStore.currentSession()
            let context = try await fetchCurrentUserUseCase.execute()
            appState.update(authContext: context)
        } catch {
            appState.markUnauthenticated()
        }
    }

    func logout() async {
        try? await tokenStore.removeSession()
        appState.markUnauthenticated()
    }
}


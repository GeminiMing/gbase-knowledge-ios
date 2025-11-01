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
        await MainActor.run {
            appState.markLoading()
        }

        do {
            _ = try await container.tokenStore.currentSession()
            let context = try await container.fetchCurrentUserUseCase.execute()
            await MainActor.run {
                container.appState.update(authContext: context)
            }
        } catch {
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


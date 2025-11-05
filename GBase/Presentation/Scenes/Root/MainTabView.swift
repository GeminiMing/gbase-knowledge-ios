import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ProjectsView()
                .tabItem {
                    Label(LocalizedStringKey.tabProjects.localized, systemImage: "folder")
                }
                .tag(AppState.MainTab.projects)

            ProfileView()
                .tabItem {
                    Label(LocalizedStringKey.tabProfile.localized, systemImage: "person.circle")
                }
                .tag(AppState.MainTab.profile)
        }
        .navigationTitle(appState.authContext?.user.name ?? "")
    }
}

#Preview {
    MainTabView()
        .environment(\.diContainer, .preview)
        .environmentObject(DIContainer.preview.appState)
}


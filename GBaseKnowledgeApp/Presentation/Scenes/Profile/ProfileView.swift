import SwiftUI

struct ProfileView: View {
    @Environment(\.diContainer) private var container
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationView {
            List {
                userSection

                Section {
                    Button {
                        Task { await viewModel.clearCache() }
                    } label: {
                        Label(LocalizedStringKey.profileClearCache.localized, systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        Task { await viewModel.logout() }
                    } label: {
                        Label(LocalizedStringKey.profileLogout.localized, systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle(LocalizedStringKey.profileTitle.localized)
            .overlay {
                if viewModel.isProcessing {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        ProgressView()
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                }
            }
            .alert(isPresented: Binding<Bool>(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            )) {
                Alert(title: Text(LocalizedStringKey.profileAlertTitle.localized),
                      message: Text(viewModel.alertMessage ?? ""),
                      dismissButton: .default(Text(LocalizedStringKey.commonOk.localized)))
            }
        }
        .onAppear {
            viewModel.configure(container: container)
        }
    }

    @ViewBuilder
    private var userSection: some View {
        if let context = appState.authContext {
            Section(header: Text(LocalizedStringKey.profileBasicInfo.localized)) {
                profileRow(icon: "person.fill", title: LocalizedStringKey.profileName.localized, value: context.user.name)
                profileRow(icon: "envelope.fill", title: LocalizedStringKey.profileEmail.localized, value: context.user.email)
                if !context.user.defaultCompanyId.isEmpty {
                    profileRow(icon: "building.2.fill", title: LocalizedStringKey.profileDefaultCompany.localized, value: context.user.defaultCompanyId)
                }
                if !context.company.companyId.isEmpty {
                    profileRow(icon: "number", title: LocalizedStringKey.profileCompanyId.localized, value: context.company.companyId)
                }
                if !context.company.userName.isEmpty {
                    profileRow(icon: "person.badge.shield.checkmark", title: LocalizedStringKey.profileCompanyUsername.localized, value: context.company.userName)
                }
                profileRow(icon: "globe", title: LocalizedStringKey.profileLanguage.localized, value: context.user.language)
            }
        } else {
            Section {
                Text(LocalizedStringKey.profileNotLoggedIn.localized)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func profileRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ProfileView()
        .environment(\.diContainer, .preview)
        .environmentObject(DIContainer.preview.appState)
}


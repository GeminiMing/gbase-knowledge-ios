import SwiftUI

struct LoginView: View {
    @Environment(\.diContainer) private var container
    @StateObject private var viewModel = LoginViewModel()
    @State private var showPassword = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Logo 和应用名称区域
                    VStack(spacing: 12) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: Color.accentColor.opacity(0.2), radius: 8, x: 0, y: 4)

                        Text("GBase")
                            .font(.system(.title2, weight: .bold))
                            .foregroundColor(.primary)

                        Text(LocalizedStringKey.loginWelcomeBack.localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 80)
                    .padding(.bottom, 48)

                    // 输入表单卡片
                    VStack(spacing: 0) {
                        // 邮箱输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStringKey.loginEmail.localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)

                            TextField(LocalizedStringKey.loginEmailPlaceholder.localized, text: $viewModel.email)
                                .textContentType(.username)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .disableAutocorrection(true)
                                .textInputAutocapitalization(.never)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }

                        Divider()
                            .padding(.leading, 16)

                        // 密码输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStringKey.loginPassword.localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)

                            HStack {
                                if showPassword {
                                    TextField(LocalizedStringKey.loginPasswordPlaceholder.localized, text: $viewModel.password)
                                        .textContentType(.password)
                                        .autocorrectionDisabled()
                                        .disableAutocorrection(true)
                                        .textInputAutocapitalization(.never)
                                        .font(.body)
                                } else {
                                    SecureField(LocalizedStringKey.loginPasswordPlaceholder.localized, text: $viewModel.password)
                                        .textContentType(.password)
                                        .autocorrectionDisabled()
                                        .disableAutocorrection(true)
                                        .textInputAutocapitalization(.never)
                                        .font(.body)
                                }

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 16))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                    // 错误提示
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                    }

                    // 登录按钮
                    Button(action: {
                        Task {
                            await viewModel.login()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty
                                        ? Color.gray.opacity(0.3)
                                        : Color.black
                                )
                                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                            
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text(LocalizedStringKey.loginButton.localized)
                                        .font(.system(.body, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            viewModel.configure(container: container)
        }
    }
}

#Preview {
    LoginView()
        .environment(\.diContainer, .preview)
}


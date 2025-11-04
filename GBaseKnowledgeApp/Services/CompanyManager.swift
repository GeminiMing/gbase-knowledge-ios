import Foundation
import Combine

/// 公司切换管理器
@MainActor
public class CompanyManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var state = CompanyState()
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    // MARK: - Dependencies

    private let apiService: CompanyAPIService
    private let tokenStore: TokenStore

    // MARK: - Initialization

    nonisolated public init(apiService: CompanyAPIService, tokenStore: TokenStore) {
        self.apiService = apiService
        self.tokenStore = tokenStore
    }

    // MARK: - Public Methods

    /// 初始化加载 - 登录后调用
    public func initialize() async {
        isLoading = true
        error = nil

        print("🚀 开始初始化公司信息...")

        do {
            // 1. 获取当前默认公司
            print("📍 步骤 1: 获取当前默认公司")
            try await fetchCurrentCompany()

            // 2. 获取可选公司列表
            print("📍 步骤 2: 获取可选公司列表")
            try await fetchAvailableCompanies()

            print("✅ 公司信息初始化完成")

        } catch {
            self.error = error
            print("❌ 初始化公司信息失败: \(error)")
            print("❌ 错误详情: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("❌ URL错误代码: \(urlError.code.rawValue)")
            }
        }

        isLoading = false
    }

    /// 获取当前默认公司
    func fetchCurrentCompany() async throws {
        print("🌐 正在调用 getMyCompanyDefault API...")
        let response = try await apiService.getMyCompanyDefault()

        if response.success {
            state.currentCompanyId = response.company.id
            state.currentCompanyName = response.company.name
            state.currentCompanyDescription = response.company.description
            state.currentCompanyCode = response.company.code
            state.needsDefaultPasswordChange = response.userSecurity.mustChangePassword

            print("✅ 当前公司: \(response.company.name)")

            // 获取用户权限
            print("🌐 正在获取用户权限...")
            try await fetchUserAuthority(companyId: response.company.id)
        } else {
            print("❌ getMyCompanyDefault 返回 success=false")
        }
    }

    /// 获取可选公司列表
    func fetchAvailableCompanies() async throws {
        let response = try await apiService.getMyCompaniesList()
        state.availableCompanies = response.companies

        print("✅ 可选公司数量: \(response.companies.count)")
        print("📋 公司列表:")
        for (index, company) in response.companies.enumerated() {
            print("  \(index + 1). \(company.name) (ID: \(company.id))")
        }
        print("🔄 hasMultipleCompanies: \(state.hasMultipleCompanies)")
    }

    /// 切换公司
    func switchCompany(to company: Company) async throws {
        isLoading = true
        error = nil

        print("🔄 开始切换公司...")
        print("📍 目标公司 ID: \(company.id)")
        print("📍 目标公司名称: \(company.name)")

        do {
            // 1. 调用切换公司 API
            print("🌐 正在调用 switchMyCompany API...")
            let response = try await apiService.switchMyCompany(companyId: company.id)

            print("📥 API 响应接收完成")
            print("📊 响应 success 字段: \(response.success)")
            print("📊 响应 loginToken 是否存在: \(response.loginToken != nil)")
            print("📊 响应 company 是否存在: \(response.company != nil)")
            print("📊 响应 authorityCodes: \(response.authorityCodes ?? [])")
            
            if let company = response.company {
                print("📊 返回的公司信息: \(company.name) (ID: \(company.id))")
            }

            guard response.success, let data = response.data else {
                print("❌ 切换公司失败: success=\(response.success)")
                if !response.success {
                    print("❌ 失败原因: API 返回 success=false")
                }
                if response.data == nil {
                    print("❌ 失败原因: 无法创建 data 对象（可能缺少必要字段）")
                    print("   - loginToken: \(response.loginToken != nil ? "存在" : "缺失")")
                    print("   - company: \(response.company != nil ? "存在" : "缺失")")
                }
                throw CompanyError.switchFailed
            }

            // 2. 更新 Keychain 中的 AuthSession
            if let loginToken = data.loginToken {
                print("🔑 开始更新 Token 到 Keychain...")
                print("🔑 accessToken 长度: \(loginToken.accessToken.count)")
                print("🔑 refreshToken 长度: \(loginToken.refreshToken.count)")
                print("🔑 accessTokenExpiresIn: \(loginToken.accessTokenExpiresIn ?? 0) 秒")
                
                let newSession = AuthSession(
                    accessToken: loginToken.accessToken,
                    refreshToken: loginToken.refreshToken,
                    expiresAt: Date().addingTimeInterval(TimeInterval(loginToken.accessTokenExpiresIn ?? 86400)),
                    tokenType: loginToken.tokenType ?? "Bearer"
                )
                try await tokenStore.save(session: newSession)
                print("✅ Token 已更新到 Keychain")
            } else {
                print("⚠️ 警告: 响应中未包含 loginToken，跳过 Token 更新")
            }

            // 3. 同时更新 UserDefaults（保持兼容性）
            if let loginToken = data.loginToken {
                updateLocalTokens(loginToken: loginToken)
            }

            // 4. 重新获取当前公司信息
            print("🔄 正在重新获取当前公司信息...")
            try await fetchCurrentCompany()

            // 5. 发送切换完成通知
            print("📢 发送公司切换完成通知...")
            NotificationCenter.default.post(
                name: .companyDidChange,
                object: nil,
                userInfo: [
                    "companyId": company.id
                ]
            )

            print("✅ 已成功切换到公司: \(company.name)")

        } catch {
            self.error = error
            print("❌ 切换公司失败: \(error)")
            print("❌ 错误类型: \(type(of: error))")
            print("❌ 错误描述: \(error.localizedDescription)")
            
            if let urlError = error as? URLError {
                print("❌ URLError 代码: \(urlError.code.rawValue)")
                print("❌ URLError 描述: \(urlError.localizedDescription)")
            }
            
            if let apiError = error as? CompanyAPIError {
                print("❌ CompanyAPIError: \(apiError.localizedDescription)")
            }
            
            throw error
        }

        isLoading = false
    }

    /// 刷新公司信息
    func refresh() async {
        do {
            try await fetchCurrentCompany()
            try await fetchAvailableCompanies()
        } catch {
            self.error = error
            print("❌ 刷新公司信息失败: \(error)")
        }
    }

    // MARK: - Private Methods

    private func fetchUserAuthority(companyId: String) async throws {
        let response = try await apiService.getUserAuthority(companyId: companyId)
        state.hasAdminConsoleAuthority = response.authorityCodes.contains("ADMIN_CONSOLE")
    }

    private func updateLocalTokens(loginToken: LoginToken) {
        // 保存到 UserDefaults
        UserDefaults.standard.set(loginToken.accessToken, forKey: "accessToken")
        UserDefaults.standard.set(loginToken.refreshToken, forKey: "refreshToken")

        // TODO: 如果使用 Keychain，在这里同步更新
        // KeychainManager.shared.save(loginToken.accessToken, forKey: "accessToken")
        // KeychainManager.shared.save(loginToken.refreshToken, forKey: "refreshToken")

        print("✅ Token 已更新")
    }
}

// MARK: - Company Error

enum CompanyError: Error, LocalizedError {
    case switchFailed
    case noCurrentCompany
    case networkError

    var errorDescription: String? {
        switch self {
        case .switchFailed:
            return "切换公司失败"
        case .noCurrentCompany:
            return "没有当前公司"
        case .networkError:
            return "网络错误"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let companyDidChange = Notification.Name("companyDidChange")
}

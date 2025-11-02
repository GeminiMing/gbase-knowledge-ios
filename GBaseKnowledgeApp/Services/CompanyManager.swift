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

    // MARK: - Initialization

    nonisolated public init(apiService: CompanyAPIService) {
        self.apiService = apiService
    }

    // MARK: - Public Methods

    /// 初始化加载 - 登录后调用
    public func initialize() async {
        isLoading = true
        error = nil

        do {
            // 1. 获取当前默认公司
            try await fetchCurrentCompany()

            // 2. 获取可选公司列表
            try await fetchAvailableCompanies()

        } catch {
            self.error = error
            print("❌ 初始化公司信息失败: \(error)")
        }

        isLoading = false
    }

    /// 获取当前默认公司
    func fetchCurrentCompany() async throws {
        let response = try await apiService.getMyCompanyDefault()

        if response.success {
            state.currentCompanyId = response.company.id
            state.currentCompanyName = response.company.name
            state.currentCompanyDescription = response.company.description
            state.currentCompanyCode = response.company.code
            state.needsDefaultPasswordChange = response.userSecurity.mustChangePassword

            // 获取用户权限
            try await fetchUserAuthority(companyId: response.company.id)

            // 检查 Agent 权限
            try await checkAgentPermission()

            print("✅ 当前公司: \(response.company.name)")
        }
    }

    /// 获取可选公司列表
    func fetchAvailableCompanies() async throws {
        let response = try await apiService.getMyCompaniesList()
        state.availableCompanies = response.companies

        print("✅ 可选公司数量: \(response.companies.count)")
    }

    /// 切换公司
    func switchCompany(to company: Company) async throws {
        isLoading = true
        error = nil

        do {
            // 1. 调用切换公司 API
            let response = try await apiService.switchMyCompany(companyId: company.id)

            guard response.success else {
                throw CompanyError.switchFailed
            }

            // 2. 更新本地 Token
            if let loginToken = response.loginToken {
                updateLocalTokens(loginToken: loginToken)
            }

            // 3. 重新获取当前公司信息
            try await fetchCurrentCompany()

            // 4. 发送切换完成通知
            NotificationCenter.default.post(
                name: .companyDidChange,
                object: nil,
                userInfo: [
                    "companyId": company.id,
                    "hasAgentPermission": state.hasAgentPermission
                ]
            )

            print("✅ 已切换到公司: \(company.name)")

        } catch {
            self.error = error
            print("❌ 切换公司失败: \(error)")
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

    private func checkAgentPermission() async throws {
        let response = try await apiService.checkAgentAuth()
        state.hasAgentPermission = response.hasPermission
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

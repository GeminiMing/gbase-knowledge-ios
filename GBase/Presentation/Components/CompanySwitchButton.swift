import SwiftUI

/// 公司切换按钮 - 显示当前公司名称，点击可切换
struct CompanySwitchButton: View {

    @ObservedObject var companyManager: CompanyManager
    @State private var showingCompanySelector = false

    var body: some View {
        Button(action: {
            showingCompanySelector = true
        }) {
            HStack(spacing: 8) {
                // 公司名称
                if let companyName = companyManager.state.currentCompanyName {
                    Text(companyName)
                        .font(.headline)
                        .foregroundColor(.primary)
                } else {
                    Text("选择公司")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                // 下拉箭头（仅在有多个公司时显示）
                if companyManager.state.hasMultipleCompanies {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .disabled(!companyManager.state.hasMultipleCompanies)
        .sheet(isPresented: $showingCompanySelector) {
            CompanySelectorView(companyManager: companyManager)
        }
    }
}

// MARK: - Current Company Display Card

/// 当前公司信息卡片 - 用于设置页面
struct CurrentCompanyCard: View {

    @ObservedObject var companyManager: CompanyManager
    @State private var showingCompanySelector = false

    var body: some View {
        Button(action: {
            if companyManager.state.hasMultipleCompanies {
                showingCompanySelector = true
            }
        }) {
            HStack(spacing: 16) {
                // 公司图标
                Circle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text((companyManager.state.currentCompanyName ?? "").prefix(1).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )

                // 公司信息
                VStack(alignment: .leading, spacing: 4) {
                    if let companyName = companyManager.state.currentCompanyName {
                        Text(companyName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    if let description = companyManager.state.currentCompanyDescription,
                       !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    // 显示公司数量提示
                    if companyManager.state.hasMultipleCompanies {
                        Text("点击切换公司 (\(companyManager.state.availableCompanies.count) 个)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                Spacer()

                // 切换图标
                if companyManager.state.hasMultipleCompanies {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!companyManager.state.hasMultipleCompanies)
        .sheet(isPresented: $showingCompanySelector) {
            CompanySelectorView(companyManager: companyManager)
        }
    }
}

// MARK: - Preview

#Preview("Switch Button") {
    let tokenStore = KeychainTokenStore()
    let companyAPIService = CompanyAPIService(tokenStore: tokenStore)
    let companyManager = CompanyManager(apiService: companyAPIService, tokenStore: tokenStore)
    VStack(spacing: 20) {
        CompanySwitchButton(companyManager: companyManager)
        CurrentCompanyCard(companyManager: companyManager)
    }
    .padding()
}

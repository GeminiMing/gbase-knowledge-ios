import SwiftUI

/// 公司选择器视图
struct CompanySelectorView: View {

    @ObservedObject var companyManager: CompanyManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if companyManager.isLoading {
                    ProgressView("加载中...")
                } else if let error = companyManager.error {
                    errorView(error: error)
                } else {
                    companyList
                }
            }
            .navigationTitle("选择公司")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await companyManager.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(companyManager.isLoading)
                }
            }
        }
    }

    // MARK: - Company List

    private var companyList: some View {
        List {
            ForEach(companyManager.state.availableCompanies) { company in
                CompanyRow(
                    company: company,
                    isSelected: company.id == companyManager.state.currentCompanyId,
                    onSelect: {
                        Task {
                            await switchToCompany(company)
                        }
                    }
                )
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Error View

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("加载失败")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("重试") {
                Task {
                    await companyManager.initialize()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Actions

    private func switchToCompany(_ company: Company) async {
        do {
            try await companyManager.switchCompany(to: company)
            // 切换成功，关闭弹窗
            dismiss()
        } catch {
            // 错误已经在 CompanyManager 中处理
            // 这里可以显示 Alert
        }
    }
}

// MARK: - Company Row

struct CompanyRow: View {
    let company: Company
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 公司图标
                Circle()
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(company.name.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(isSelected ? .white : .primary)
                    )

                // 公司信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(company.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let description = company.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let companyAPIService = CompanyAPIService()
    let tokenStore = KeychainTokenStore()
    let companyManager = CompanyManager(apiService: companyAPIService, tokenStore: tokenStore)
    CompanySelectorView(companyManager: companyManager)
}

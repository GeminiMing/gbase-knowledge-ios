# iOS 公司切换功能实现文档

## 📁 文件结构

已创建的文件：
```
GBaseKnowledgeApp/
├── Domain/Entities/
│   └── Company.swift                          # 公司数据模型
├── Services/
│   ├── CompanyAPIService.swift                # 公司 API 服务
│   └── CompanyManager.swift                   # 公司切换管理器
└── Presentation/Components/
    ├── CompanySelectorView.swift              # 公司选择器视图
    └── CompanySwitchButton.swift              # 公司切换按钮组件
```

---

## 🚀 快速开始

### 1. 配置 API Base URL

在 [CompanyAPIService.swift](GBaseKnowledgeApp/Services/CompanyAPIService.swift#L9) 中修改：

```swift
init(baseURL: String = "https://your-api.com", session: URLSession = .shared) {
    self.baseURL = baseURL
    self.session = session
}
```

### 2. 在 App 启动时初始化

```swift
@main
struct GBaseKnowledgeApp: App {
    @StateObject private var companyManager = CompanyManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(companyManager)
                .task {
                    // 登录成功后初始化公司信息
                    await companyManager.initialize()
                }
        }
    }
}
```

### 3. 在页面中使用

#### 方式 A：使用切换按钮（导航栏）

```swift
struct HomeView: View {
    @EnvironmentObject var companyManager: CompanyManager

    var body: some View {
        NavigationView {
            VStack {
                Text("首页内容")
            }
            .navigationTitle("首页")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    CompanySwitchButton(companyManager: companyManager)
                }
            }
        }
    }
}
```

#### 方式 B：使用公司信息卡片（设置页面）

```swift
struct SettingsView: View {
    @EnvironmentObject var companyManager: CompanyManager

    var body: some View {
        List {
            Section("当前公司") {
                CurrentCompanyCard(companyManager: companyManager)
            }

            Section("其他设置") {
                // 其他设置项...
            }
        }
        .navigationTitle("设置")
    }
}
```

---

## 📋 API 接口说明

### 1. 获取当前默认公司
```
GET /user/my/company/default

Response:
{
    "success": true,
    "company": {
        "id": "xxx",
        "name": "公司名称",
        "code": "COMPANY_CODE",
        "description": "公司描述"
    },
    "userSecurity": {
        "mustChangePassword": false
    }
}
```

### 2. 获取用户所有公司
```
GET /user/my/companies

Response:
{
    "companies": [
        {
            "id": "xxx",
            "name": "公司A",
            "code": "A",
            "description": "..."
        },
        {
            "id": "yyy",
            "name": "公司B",
            "code": "B",
            "description": "..."
        }
    ]
}
```

### 3. 切换公司
```
POST /user/my/company/default
Content-Type: application/json

{
    "companyId": "xxx"
}

Response:
{
    "success": true,
    "loginToken": {
        "accessToken": "new-token",
        "refreshToken": "new-refresh-token",
        "expiresIn": 3600,
        "tokenType": "Bearer"
    },
    "company": { ... },
    "authorityCodes": ["ADMIN_CONSOLE", ...]
}
```

### 4. 获取用户权限
```
GET /user/{companyId}/authority

Response:
{
    "authorityCodes": ["ADMIN_CONSOLE", "USER_MANAGEMENT", ...]
}
```

### 5. 检查 Agent 权限
```
GET /agent/auth/check

Response:
{
    "hasPermission": true
}
```

---

## 🔄 切换公司流程

### CompanyManager 自动处理的步骤：

1. **调用切换 API**
   ```swift
   let response = try await apiService.switchMyCompany(companyId: company.id)
   ```

2. **更新本地 Token**
   ```swift
   UserDefaults.standard.set(loginToken.accessToken, forKey: "accessToken")
   UserDefaults.standard.set(loginToken.refreshToken, forKey: "refreshToken")
   ```

3. **重新获取公司信息**
   ```swift
   try await fetchCurrentCompany()
   ```

4. **发送切换完成通知**
   ```swift
   NotificationCenter.default.post(name: .companyDidChange, object: nil)
   ```

### 监听公司切换事件：

```swift
NotificationCenter.default.addObserver(
    forName: .companyDidChange,
    object: nil,
    queue: .main
) { notification in
    if let userInfo = notification.userInfo,
       let companyId = userInfo["companyId"] as? String {
        print("公司已切换到: \(companyId)")
        // 重新加载数据
        Task {
            await reloadData()
        }
    }
}
```

---

## 🎨 UI 组件说明

### 1. CompanySelectorView
全屏公司选择器，显示所有可用公司列表：
- ✅ 显示公司名称和描述
- ✅ 高亮当前选中的公司
- ✅ 支持下拉刷新
- ✅ 错误处理和重试

### 2. CompanySwitchButton
紧凑型公司切换按钮：
- ✅ 显示当前公司名称
- ✅ 仅在有多个公司时可点击
- ✅ 点击弹出公司选择器
- ✅ 适合放在导航栏

### 3. CurrentCompanyCard
公司信息展示卡片：
- ✅ 显示公司图标（首字母）
- ✅ 显示公司名称和描述
- ✅ 显示可用公司数量
- ✅ 适合放在设置页面

---

## 📊 状态管理

### CompanyState 包含的状态：

```swift
struct CompanyState {
    var currentCompanyId: String?              // 当前公司 ID
    var currentCompanyName: String?            // 当前公司名称
    var currentCompanyDescription: String?     // 当前公司描述
    var currentCompanyCode: String?            // 当前公司编码（不显示）
    var availableCompanies: [Company]          // 可用公司列表
    var hasAdminConsoleAuthority: Bool         // 是否有管理员权限
    var hasAgentPermission: Bool               // 是否有 Agent 权限
    var needsDefaultPasswordChange: Bool       // 是否需要修改默认密码
}
```

### 计算属性：

```swift
// 获取当前公司对象
var currentCompany: Company? {
    guard let id = currentCompanyId else { return nil }
    return availableCompanies.first { $0.id == id }
}

// 是否有多个公司
var hasMultipleCompanies: Bool {
    return availableCompanies.count > 1
}
```

---

## ⚠️ 注意事项

### 1. Token 存储
当前使用 `UserDefaults` 存储 Token，**生产环境建议使用 Keychain**：

```swift
// TODO: 替换为 Keychain 存储
KeychainManager.shared.save(loginToken.accessToken, forKey: "accessToken")
KeychainManager.shared.save(loginToken.refreshToken, forKey: "refreshToken")
```

### 2. 错误处理
切换公司失败时会：
- ✅ 保持原有公司状态
- ✅ 显示错误信息
- ✅ 允许用户重试
- ❌ **不会**自动回滚 Token（需要后端支持）

### 3. 网络失败
如果切换请求失败：
- ✅ 保持原有 Token 不变
- ✅ 保持原有公司不变
- ✅ 提示用户错误信息

### 4. 数据刷新
切换公司后，应用需要：
- 🔄 重新加载业务数据
- 🔄 重新加载部门信息
- 🔄 重新加载用户权限
- 🔄 清理旧公司的缓存

监听 `companyDidChange` 通知来触发这些刷新操作。

---

## 🧪 测试清单

- [ ] 登录后能正确获取当前公司
- [ ] 能正确显示所有可用公司列表
- [ ] 切换公司成功后 UI 更新
- [ ] Token 正确更新到本地存储
- [ ] 切换失败时显示错误提示
- [ ] 网络失败时不影响当前状态
- [ ] 只有一个公司时不显示切换按钮
- [ ] 多个公司时可以正常切换
- [ ] 下拉刷新能重新加载公司列表
- [ ] 公司切换通知正确发送

---

## 🔧 后续优化建议

1. **添加 Keychain 支持**
   - 使用 Keychain 存储敏感的 Token
   - 防止 Token 泄露

2. **添加切换确认弹窗**
   - 在切换前询问用户确认
   - 特别是有未保存数据时

3. **优化加载体验**
   - 添加骨架屏
   - 优化加载动画

4. **添加缓存机制**
   - 缓存公司列表到本地
   - 减少网络请求

5. **添加离线支持**
   - 离线时显示缓存的公司信息
   - 网络恢复后自动同步

---

## 📞 使用示例

完整的使用示例：

```swift
import SwiftUI

@main
struct GBaseKnowledgeApp: App {
    @StateObject private var companyManager = CompanyManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(companyManager)
                .task {
                    // 登录成功后初始化
                    await companyManager.initialize()
                }
                .onReceive(NotificationCenter.default.publisher(for: .companyDidChange)) { notification in
                    // 公司切换后的处理
                    if let userInfo = notification.userInfo {
                        print("公司已切换:", userInfo)
                    }
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var companyManager: CompanyManager

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var companyManager: CompanyManager

    var body: some View {
        NavigationView {
            VStack {
                if let companyName = companyManager.state.currentCompanyName {
                    Text("当前公司: \(companyName)")
                        .font(.headline)
                }
            }
            .navigationTitle("首页")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    CompanySwitchButton(companyManager: companyManager)
                }
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var companyManager: CompanyManager

    var body: some View {
        NavigationView {
            List {
                Section("公司信息") {
                    CurrentCompanyCard(companyManager: companyManager)
                }

                Section("权限") {
                    Toggle("管理员权限", isOn: .constant(companyManager.state.hasAdminConsoleAuthority))
                        .disabled(true)
                    Toggle("Agent 权限", isOn: .constant(companyManager.state.hasAgentPermission))
                        .disabled(true)
                }
            }
            .navigationTitle("设置")
        }
    }
}
```

现在你可以在应用中轻松实现公司切换功能！🎉

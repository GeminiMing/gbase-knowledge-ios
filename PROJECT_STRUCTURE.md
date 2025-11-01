# 项目目录结构

```
GBaseKnowledgeApp/
├── .gitignore                    # Git 忽略文件配置
├── README.md                     # 项目说明文档
├── GBaseKnowledgeApp.xcodeproj/ # Xcode 项目文件
│   ├── project.pbxproj
│   └── project.xcworkspace/
│       └── xcshareddata/
│           └── swiftpm/
│               └── Package.resolved  # Swift Package 依赖版本锁定
│
├── GBaseKnowledgeApp/            # 主应用代码目录
│   ├── Application/              # 应用入口和配置
│   │   ├── AppEntry.swift
│   │   ├── AppState.swift
│   │   └── DIContainer.swift
│   │
│   ├── Presentation/             # 展示层
│   │   ├── Components/           # 可复用组件
│   │   │   └── WaveformView.swift
│   │   └── Scenes/              # 页面视图
│   │       ├── Login/           # 登录页
│   │       ├── Projects/        # 项目列表页
│   │       ├── Recorder/        # 录音页
│   │       ├── Profile/         # 个人资料页
│   │       └── Root/            # 根视图
│   │
│   ├── Domain/                   # 领域层
│   │   ├── Entities/            # 业务实体
│   │   ├── Repositories/        # 仓储接口
│   │   └── UseCases/            # 业务用例
│   │
│   ├── Data/                     # 数据层
│   │   ├── API/                 # 网络请求
│   │   ├── Models/              # DTO 和映射器
│   │   └── Repository/          # 仓储实现
│   │
│   ├── Persistence/              # 持久化层
│   │   ├── Models/              # Realm 数据模型
│   │   ├── RealmConfigurator.swift
│   │   └── RecordingLocalStore.swift
│   │
│   ├── Services/                 # 服务层
│   │   ├── AudioRecorderService.swift
│   │   ├── AudioPlayerService.swift
│   │   ├── FileStorageService.swift
│   │   ├── RecordingUploadService.swift
│   │   ├── KeychainTokenStore.swift
│   │   └── NetworkMonitor.swift
│   │
│   ├── Utilities/                # 工具类
│   │   ├── Localization.swift
│   │   ├── Logger.swift
│   │   ├── CryptoHelper.swift
│   │   └── DateFormatter+Extensions.swift
│   │
│   ├── Resources/                # 本地化资源（推荐使用）
│   │   ├── Base.lproj/          # 基础语言（英文）
│   │   ├── zh-Hans.lproj/       # 简体中文
│   │   ├── en.lproj/            # 英文
│   │   └── ja.lproj/           # 日文
│   │
│   ├── Assets.xcassets/          # 图片资源
│   │   ├── AppIcon.appiconset/ # 应用图标
│   │   └── Logo.imageset/      # Logo 图片
│   │
│   ├── Base.lproj/              # ⚠️ 重复的本地化文件（应删除）
│   ├── en.lproj/                # ⚠️ 重复的本地化文件（应删除）
│   ├── ja.lproj/                # ⚠️ 重复的本地化文件（应删除）
│   └── zh-Hans.lproj/           # ⚠️ 重复的本地化文件（应删除）
│
└── realm-swift-master/          # ⚠️ Realm Swift 本地包（157MB，不应提交）
    └── (应作为 Git Submodule 或通过 SPM 引用)
```

## 📋 上传前需要处理的事项

### 1. ✅ 创建 .gitignore 文件
已创建 `.gitignore`，包含：
- Xcode 用户数据（xcuserdata）
- 构建产物（build/, DerivedData/）
- 系统文件（.DS_Store）
- 临时文件

### 2. ⚠️ 清理重复的本地化文件
**问题**：`GBaseKnowledgeApp/` 目录下有重复的 `.lproj` 文件夹，与 `Resources/` 下的重复。

**建议**：
- **保留** `Resources/` 下的本地化文件（这是标准位置）
- **删除** `GBaseKnowledgeApp/` 下直接放置的 `.lproj` 文件夹

### 3. ⚠️ 处理 realm-swift-master（157MB）
**问题**：`realm-swift-master` 目录很大，不应该直接提交到 Git。

**建议方案**：
- **方案 A（推荐）**：在 Xcode 中移除本地包引用，改用远程 SPM 依赖
  - 项目已配置为使用本地路径 `../realm-swift-master`
  - 可以改为使用 GitHub URL：`https://github.com/realm/realm-swift.git`
  
- **方案 B**：作为 Git Submodule
  ```bash
  git submodule add https://github.com/realm/realm-swift.git realm-swift-master
  ```

### 4. 📝 文档文件
- `README.md` - ✅ 保留（项目说明）
- `LOCALIZATION_DEBUG.md` - ⚠️ 调试文档，可删除或移至 docs/
- `REALM_DEPENDENCY_FIX.md` - ⚠️ 临时文档，可删除或移至 docs/

### 5. 🔒 敏感信息检查
检查以下文件是否包含敏感信息：
- API 密钥
- 认证 Token
- 服务器地址（如果是内网地址）

## 🚀 上传到 Git 的步骤

1. **清理重复文件**：
   ```bash
   cd GBaseKnowledgeApp
   rm -rf GBaseKnowledgeApp/Base.lproj
   rm -rf GBaseKnowledgeApp/en.lproj
   rm -rf GBaseKnowledgeApp/ja.lproj
   rm -rf GBaseKnowledgeApp/zh-Hans.lproj
   ```

2. **处理 realm-swift-master**：
   - 如果使用方案 A，在 Xcode 中改为远程 SPM
   - 如果使用方案 B，添加为 submodule

3. **添加文件到 Git**：
   ```bash
   git add .gitignore
   git add README.md
   git add GBaseKnowledgeApp/
   git add GBaseKnowledgeApp.xcodeproj/
   ```

4. **提交**：
   ```bash
   git commit -m "Initial commit: GBase Knowledge App"
   ```

5. **推送到远程**：
   ```bash
   git remote add origin <your-repo-url>
   git push -u origin main
   ```

## 📊 目录大小统计

- `GBaseKnowledgeApp/` - 840KB（应用代码）
- `GBaseKnowledgeApp.xcodeproj/` - 72KB（项目文件）
- `realm-swift-master/` - 157MB（⚠️ 需要处理）
- 文档文件 - 约 20KB

**总计**：约 158MB（如果包含 realm-swift-master）

## ✅ 最终推荐结构

```
GBaseKnowledgeApp/
├── .gitignore
├── README.md
├── GBaseKnowledgeApp.xcodeproj/
├── GBaseKnowledgeApp/
│   ├── Application/
│   ├── Presentation/
│   ├── Domain/
│   ├── Data/
│   ├── Persistence/
│   ├── Services/
│   ├── Utilities/
│   ├── Resources/          # ✅ 只保留这个本地化目录
│   └── Assets.xcassets/
└── (realm-swift 通过 SPM 或 submodule 引用)
```


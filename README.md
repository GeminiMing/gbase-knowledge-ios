# GBase Knowledge App

一个基于 SwiftUI 开发的 iOS 应用程序，用于会议录音管理和知识库管理。

## 📱 功能特性

- **用户认证**：支持邮箱密码登录，Token 自动刷新
- **项目管理**：查看和管理项目列表，支持搜索和分页
- **会议录音**：实时音频录制，支持波形可视化显示
- **本地存储**：使用 Realm 数据库存储录音元数据
- **录音上传**：支持断点续传和进度显示
- **录音播放**：本地录音播放功能
- **多语言支持**：支持中文（简体）、日文、英文
- **用户资料**：个人信息展示和本地缓存清理

## 🛠 技术栈

### 架构模式
- **Clean Architecture**：采用领域驱动设计（DDD）分层架构
  - **Presentation Layer**：SwiftUI 视图和 ViewModel
  - **Domain Layer**：业务实体、用例和仓储接口
  - **Data Layer**：API 客户端、DTO 和仓储实现
  - **Persistence Layer**：Realm 数据库和本地存储

### 核心技术
- **SwiftUI**：现代化的声明式 UI 框架
- **Combine**：响应式编程框架
- **Realm Swift**：本地数据库存储
- **URLSession**：网络请求处理
- **AVFoundation**：音频录制和播放
- **Keychain**：安全存储用户凭证

### 设计模式
- **依赖注入（DI）**：通过 `DIContainer` 统一管理依赖
- **Repository Pattern**：数据访问抽象层
- **Use Case Pattern**：业务逻辑封装
- **MVVM**：视图和业务逻辑分离

## 📁 项目结构

```
GBaseKnowledgeApp/
├── Application/                    # 应用入口和配置
│   ├── AppEntry.swift             # 应用入口点
│   ├── AppState.swift             # 全局应用状态管理
│   └── DIContainer.swift          # 依赖注入容器
│
├── Presentation/                  # 展示层
│   ├── Components/                # 可复用组件
│   │   └── WaveformView.swift     # 波形可视化组件
│   └── Scenes/                    # 页面视图
│       ├── Login/                 # 登录页面
│       ├── Projects/              # 项目列表页面
│       ├── Recorder/              # 录音页面
│       ├── Profile/               # 个人资料页面
│       └── Root/                  # 根视图和标签页
│
├── Domain/                        # 领域层
│   ├── Entities/                  # 业务实体
│   │   ├── User.swift
│   │   ├── Project.swift
│   │   ├── Meeting.swift
│   │   └── Recording.swift
│   ├── Repositories/              # 仓储接口定义
│   │   ├── AuthRepository.swift
│   │   ├── ProjectRepository.swift
│   │   ├── MeetingRepository.swift
│   │   └── RecordingRepository.swift
│   └── UseCases/                  # 业务用例
│       ├── AuthUseCases.swift
│       ├── ProjectUseCases.swift
│       ├── MeetingUseCases.swift
│       └── RecordingUseCases.swift
│
├── Data/                          # 数据层
│   ├── API/                       # 网络请求
│   │   ├── APIClient.swift        # API 客户端
│   │   ├── APIConfiguration.swift # API 配置
│   │   ├── RequestBuilder.swift  # 请求构建器
│   │   ├── Endpoint.swift        # 端点定义
│   │   ├── APIError.swift        # 错误处理
│   │   └── NetworkLoggerInterceptor.swift # 网络日志拦截器
│   ├── Models/                    # 数据传输对象
│   │   ├── DTO/                   # DTO 定义
│   │   │   ├── AuthDTO.swift
│   │   │   ├── ProjectDTO.swift
│   │   │   ├── MeetingDTO.swift
│   │   │   └── RecordingDTO.swift
│   │   └── Mappers/               # DTO 映射器
│   │       ├── AuthMapper.swift
│   │       ├── ProjectMapper.swift
│   │       ├── MeetingMapper.swift
│   │       └── RecordingMapper.swift
│   └── Repository/                # 仓储实现
│       ├── RemoteAuthRepository.swift
│       ├── RemoteProjectRepository.swift
│       ├── RemoteMeetingRepository.swift
│       └── RemoteRecordingRepository.swift
│
├── Persistence/                   # 持久化层
│   ├── Models/                    # Realm 数据模型
│   │   └── LocalRecordingObject.swift
│   ├── RealmConfigurator.swift    # Realm 配置
│   └── RecordingLocalStore.swift # 本地存储接口实现
│
├── Services/                      # 服务层
│   ├── AudioRecorderService.swift      # 音频录制服务
│   ├── AudioPlayerService.swift        # 音频播放服务
│   ├── FileStorageService.swift        # 文件存储服务
│   ├── RecordingUploadService.swift    # 录音上传服务
│   ├── KeychainTokenStore.swift        # Token 存储服务
│   └── NetworkMonitor.swift            # 网络监控服务
│
├── Utilities/                     # 工具类
│   ├── Localization.swift        # 本地化支持
│   ├── Logger.swift              # 日志工具
│   ├── CryptoHelper.swift        # 加密工具
│   └── DateFormatter+Extensions.swift # 日期格式化扩展
│
├── Resources/                     # 资源文件
│   ├── Base.lproj/               # 基础本地化
│   ├── zh-Hans.lproj/            # 简体中文
│   ├── en.lproj/                 # 英文
│   └── ja.lproj/                 # 日文
│
└── Assets.xcassets/              # 图片资源
    ├── AppIcon.appiconset/       # 应用图标
    └── Logo.imageset/            # Logo 图片
```

## 🔧 依赖项

### Swift Package Manager
- **RealmSwift**：本地数据库（通过本地 Swift Package）

## 📦 核心模块说明

### 1. 认证模块 (`Auth`)
- 邮箱密码登录
- Token 自动刷新
- Keychain 安全存储

### 2. 项目管理模块 (`Projects`)
- 项目列表展示（仅显示所有者/贡献者）
- 搜索和分页功能
- 项目详情和会议创建

### 3. 录音模块 (`Recording`)
- 实时音频录制
- 波形可视化（WaveformView）
- 录音文件本地存储
- 断点续传上传
- 录音播放和删除

### 4. 本地存储模块 (`Persistence`)
- Realm 数据库配置
- 录音元数据存储
- 本地文件管理

### 5. 多语言支持 (`Localization`)
- 支持中文（简体）、日文、英文
- 动态语言切换
- 本地化字符串管理

## 🚀 构建和运行

### 环境要求
- Xcode 15.0+
- iOS 16.0+
- Swift 5.9+

### 构建步骤

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd GBaseKnowledgeApp
   ```

2. **安装依赖**
   - 打开 `GBaseKnowledgeApp.xcodeproj`
   - Xcode 会自动解析 Swift Package Manager 依赖
   - 如果 Realm 依赖未解析，请执行：
     ```bash
     xcodebuild -resolvePackageDependencies -project GBaseKnowledgeApp.xcodeproj
     ```

3. **配置 API**
   - 检查 `Data/API/APIConfiguration.swift` 中的 API 配置
   - 确保开发环境配置正确

4. **运行项目**
   - 选择目标设备（模拟器或真机）
   - 按 `Cmd + R` 运行

## 📱 主要功能流程

### 登录流程
1. 用户输入邮箱和密码
2. 调用登录 API
3. 保存 Token 到 Keychain
4. 获取用户信息和上下文
5. 跳转到项目列表

### 录音流程
1. 选择项目并创建会议
2. 进入录音页面
3. 开始录音（显示波形）
4. 停止录音并保存到本地
5. 自动上传到服务器（支持断点续传）
6. 上传完成后更新状态

### 项目列表流程
1. 加载项目列表（分页）
2. 支持搜索过滤
3. 点击项目创建会议并进入录音页

## 🔐 安全特性

- Token 存储在 Keychain 中
- 网络请求自动携带认证 Token
- Token 过期自动刷新
- 敏感数据加密存储

## 📝 代码规范

- 遵循 Swift API 设计指南
- 使用 `@MainActor` 标记 UI 相关代码
- 错误处理使用 `Result` 类型和自定义错误枚举
- 视图使用 SwiftUI 声明式语法
- ViewModel 使用 `ObservableObject` 协议

## 🌐 多语言支持

应用支持以下语言：
- 简体中文（zh-Hans）
- 英文（en）
- 日文（ja）

本地化文件位于 `Resources/` 目录下的对应 `.lproj` 文件夹中。

## 📄 许可证

[根据实际情况添加许可证信息]

## 🤝 贡献

欢迎提交 Issue 和 Pull Request。


# Apple Watch 集成配置指南

本指南将帮助你在 Xcode 中为 GBase 项目添加 Apple Watch 支持。

## 📋 前提条件

- Xcode 15.0 或更高版本
- watchOS 10.0 或更高版本的 SDK
- 配对的 iPhone 和 Apple Watch（用于测试）

## 🔧 配置步骤

### 1. 在 Xcode 中添加 Watch App Target

1. 打开 `GBase.xcodeproj`
2. 在 Xcode 中，选择 **File > New > Target...**
3. 选择 **watchOS > App**
4. 点击 **Next**
5. 配置如下：
   - **Product Name**: `GBase Watch App`
   - **Bundle Identifier**: `com.sparticle.gbase.watchkitapp`
   - **Language**: Swift
   - **User Interface**: SwiftUI
   - **Include Notification Scene**: 不勾选（暂时不需要）
6. 点击 **Finish**
7. 当提示是否激活 scheme 时，点击 **Activate**

### 2. 添加已创建的文件到 Watch Target

1. 在 Project Navigator 中找到 `GBase Watch App` 文件夹
2. 删除 Xcode 自动生成的文件（如果有的话）
3. 将以下文件拖拽到 `GBase Watch App` group 中：
   - `GBase Watch App/GBaseWatchApp.swift`
   - `GBase Watch App/ContentView.swift`
   - `GBase Watch App/RecorderViewModel.swift`
   - `GBase Watch App/Info.plist`
   - `GBase Watch App/zh-Hans.lproj/`
   - `GBase Watch App/en.lproj/`
   - `GBase Watch App/ja.lproj/`

4. 选中每个文件，在右侧的 **Target Membership** 中确保只勾选 `GBase Watch App`

### 3. 配置 Watch App 的 Build Settings

1. 选择项目文件（GBase）
2. 选择 `GBase Watch App` target
3. 在 **General** 标签页：
   - **Display Name**: GBase
   - **Bundle Identifier**: `com.sparticle.gbase.watchkitapp`
   - **Version**: 1.0
   - **Build**: 1
   - **Deployment Info**:
     - **iOS Deployment Target**: watchOS 10.0（或你需要的最低版本）

4. 在 **Signing & Capabilities** 标签页：
   - 勾选 **Automatically manage signing**
   - 选择你的 **Team**: Sparticle Inc
   - 确保 **Signing Certificate** 正确

### 4. 添加 Watch Connectivity Capability

#### 为 iOS App 添加 Capability：

1. 选择 `GBase` (iOS) target
2. 切换到 **Signing & Capabilities** 标签页
3. 点击 **+ Capability**
4. 搜索并添加 **Background Modes**
5. 勾选以下选项：
   - ✅ Audio, AirPlay, and Picture in Picture（已有）
   - ✅ Background fetch

#### 为 Watch App 添加 Capability：

1. 选择 `GBase Watch App` target
2. 切换到 **Signing & Capabilities** 标签页
3. 点击 **+ Capability**
4. 搜索并添加 **Background Modes**
5. 勾选以下选项：
   - ✅ Audio, AirPlay, and Picture in Picture

### 5. 更新 iOS App 的 Info.plist

确保 iOS App 的 Info.plist 包含 WatchKit 支持（Xcode 会自动添加）

### 6. 配置 App Groups（可选，用于数据共享）

#### 为 iOS App 添加 App Groups：

1. 选择 `GBase` (iOS) target
2. **Signing & Capabilities** > **+ Capability** > **App Groups**
3. 添加一个新的 App Group: `group.com.sparticle.gbase`

#### 为 Watch App 添加 App Groups：

1. 选择 `GBase Watch App` target
2. **Signing & Capabilities** > **+ Capability** > **App Groups**
3. 选择同样的 App Group: `group.com.sparticle.gbase`

### 7. 添加文件到正确的 Target

确保以下文件被添加到对应的 target：

#### iOS Target (`GBase`):
- `GBase/Services/WatchConnectivityService.swift` ✅
- `GBase/Services/FileStorageService.swift`（已有，已更新）✅
- 所有其他 iOS 代码

#### Watch Target (`GBase Watch App`):
- `GBase Watch App/GBaseWatchApp.swift` ✅
- `GBase Watch App/ContentView.swift` ✅
- `GBase Watch App/RecorderViewModel.swift` ✅
- `GBase Watch App/Info.plist` ✅
- 多语言文件夹 ✅

### 8. 验证配置

1. 在 Xcode 顶部的 scheme 选择器中，选择 `GBase Watch App`
2. 选择一个模拟器或真机（需要配对的 iPhone + Apple Watch）
3. 点击 Run (⌘R)
4. 应用应该能够成功构建和运行

## 🎯 功能测试

### 测试 Watch App 录音功能：

1. 在 Apple Watch（模拟器或真机）上启动 GBase
2. 点击红色的麦克风按钮开始录音
3. 录音界面应该显示时长和波形
4. 点击停止按钮结束录音

### 测试 iPhone 同步功能：

1. 确保 iPhone 上的 GBase App 正在运行（前台或后台）
2. 在 Watch 上完成录音后，录音应该自动传输到 iPhone
3. 打开 iPhone 上的 GBase App
4. 切换到 **草稿** (Drafts) 标签页
5. 应该能看到从 Watch 传来的录音，名称格式为 "Watch Recording YYYY-MM-DD HH:mm"

## 📱 设备要求

- **模拟器测试**: 需要同时运行 iPhone 模拟器和 Apple Watch 模拟器（Xcode 会自动配对）
- **真机测试**: 需要一台 iPhone 和一块配对的 Apple Watch

## 🐛 常见问题排查

### 问题：WatchConnectivity 无法连接

**解决方案**:
- 确保 iPhone 和 Watch 都运行着对应的 App
- 检查两个 target 都正确添加了 Background Modes capability
- 重启两个设备/模拟器

### 问题：录音无法传输到 iPhone

**解决方案**:
- 检查 iPhone App 是否在运行
- 查看 Xcode 控制台的日志输出
- 确保 WatchConnectivityService 已正确初始化

### 问题：权限请求未显示

**解决方案**:
- 检查 Watch App 的 Info.plist 是否包含 `NSMicrophoneUsageDescription`
- 检查多语言文件（InfoPlist.strings）是否正确配置
- 重新安装 App

### 问题：编译错误

**解决方案**:
- Clean Build Folder (⇧⌘K)
- 删除 DerivedData: `~/Library/Developer/Xcode/DerivedData/`
- 重启 Xcode

## 📝 代码集成清单

已完成的代码文件：

- ✅ `GBase Watch App/GBaseWatchApp.swift` - Watch App 入口
- ✅ `GBase Watch App/ContentView.swift` - Watch UI 界面
- ✅ `GBase Watch App/RecorderViewModel.swift` - Watch 录音逻辑
- ✅ `GBase Watch App/Info.plist` - Watch 配置
- ✅ `GBase Watch App/*/InfoPlist.strings` - 多语言权限说明
- ✅ `GBase/Services/WatchConnectivityService.swift` - iPhone 端同步服务
- ✅ `GBase/Services/FileStorageService.swift` - 文件存储（已更新）
- ✅ `GBase/Application/DIContainer.swift` - 依赖注入（已更新）

## 🚀 下一步

配置完成后，你可以：

1. 自定义 Watch App 的 UI 外观
2. 添加更多功能（如查看历史录音、删除录音等）
3. 优化录音传输逻辑
4. 添加 Watch Complications（表盘小组件）

## 📚 参考资料

- [Apple Watch App 开发文档](https://developer.apple.com/documentation/watchos-apps)
- [WatchConnectivity 框架](https://developer.apple.com/documentation/watchconnectivity)
- [SwiftUI for watchOS](https://developer.apple.com/tutorials/swiftui/)

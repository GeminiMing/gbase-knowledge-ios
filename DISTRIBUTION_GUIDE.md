# iOS App 分发指南

## 📱 分发方式选择

### 1. TestFlight（推荐用于测试）

**优点：**
- ✅ 最多支持 10,000 名外部测试员
- ✅ 无需用户提供 UDID
- ✅ 用户可以直接从 App Store 下载 TestFlight 安装
- ✅ 支持自动更新
- ✅ 可以收集崩溃日志和反馈

**缺点：**
- ⚠️ 需要 Apple Developer 账号（$99/年）
- ⚠️ 首次提交需要 App Review（约 1-2 天）
- ⚠️ 测试版本 90 天后自动过期

**适用场景：** 内部测试、Beta 测试、准备上架前的测试

---

### 2. Ad Hoc 分发

**优点：**
- ✅ 不需要审核
- ✅ 可以立即分发

**缺点：**
- ⚠️ 需要收集每个测试设备的 UDID
- ⚠️ 最多支持 100 台设备（每年）
- ⚠️ 需要为每台设备单独配置
- ⚠️ 安装比较麻烦（需要通过邮件或下载工具）

**适用场景：** 小规模内部测试（< 100 人）

---

### 3. 企业分发（Enterprise）

**优点：**
- ✅ 无设备数量限制
- ✅ 不需要审核

**缺点：**
- ⚠️ 需要 Apple Enterprise 账号（$299/年）
- ⚠️ 仅限公司内部员工使用（违规会被取消账号）

**适用场景：** 大型企业内部应用

---

## 🚀 TestFlight 分发步骤（推荐）

### Step 1: 准备工作

1. **确保有 Apple Developer 账号**
   - 访问：https://developer.apple.com
   - 注册并支付 $99/年

2. **在 App Store Connect 创建 App**
   - 访问：https://appstoreconnect.apple.com
   - 点击「我的 App」→「+」→「新建 App」
   - 填写 App 信息（名称、语言、Bundle ID 等）

3. **配置证书和描述文件**
   - 在 Xcode 中：`Signing & Capabilities`
   - 选择 Team（你的开发者账号）
   - Xcode 会自动配置证书

### Step 2: 打包上传

#### 方式 A：使用 Xcode（简单）

1. **选择设备为 "Any iOS Device"**
   ```
   Product → Destination → Any iOS Device (arm64)
   ```

2. **创建 Archive**
   ```
   Product → Archive
   ```

3. **上传到 App Store Connect**
   - Archive 完成后会自动打开 Organizer
   - 选择刚创建的 Archive
   - 点击「Distribute App」
   - 选择「App Store Connect」
   - 点击「Upload」
   - 等待处理完成（5-30 分钟）

#### 方式 B：使用命令行

```bash
cd /path/to/GBaseKnowledgeApp

# 1. 创建 Archive
xcodebuild -scheme GBaseKnowledgeApp \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$PWD/build/GBaseKnowledgeApp.xcarchive" \
  archive

# 2. 导出 IPA
xcodebuild -exportArchive \
  -archivePath "$PWD/build/GBaseKnowledgeApp.xcarchive" \
  -exportPath "$PWD/build" \
  -exportOptionsPlist ExportOptions.plist

# 3. 上传到 App Store Connect
xcrun altool --upload-app \
  --type ios \
  --file "$PWD/build/GBaseKnowledgeApp.ipa" \
  --username "your-apple-id@email.com" \
  --password "your-app-specific-password"
```

### Step 3: 配置 TestFlight

1. **进入 App Store Connect**
   - 选择你的 App
   - 点击「TestFlight」标签

2. **添加测试员**

   **内部测试员（最多 100 人）：**
   - 点击「App Store Connect 用户」
   - 添加有 App Store Connect 访问权限的用户
   - 无需审核，立即可以测试

   **外部测试员（最多 10,000 人）：**
   - 点击左侧「外部测试」
   - 创建新的测试组
   - 添加测试员邮箱
   - 首次提交需要 Beta Review（1-2 天）
   - 之后的更新无需审核

3. **分享测试链接**
   - TestFlight 会自动发送邮件邀请给测试员
   - 或者复制公开链接分享（最多 10,000 人）

### Step 4: 测试员安装

测试员需要：
1. 在 App Store 下载「TestFlight」App
2. 打开邀请邮件中的链接，或输入邀请码
3. 在 TestFlight 中安装测试版

---

## 📦 Ad Hoc 分发步骤

### Step 1: 收集设备 UDID

让测试用户提供设备 UDID：

**方法 1：iTunes/Finder**
1. 将 iPhone 连接到 Mac
2. 打开 Finder（macOS Catalina+）或 iTunes
3. 点击设备名称
4. 点击序列号，会显示 UDID
5. 右键复制

**方法 2：通过网站**
- 访问：https://get.udid.io
- 用户打开网站，点击安装描述文件
- UDID 会显示在网页上

### Step 2: 在 Developer Portal 注册设备

1. 访问：https://developer.apple.com/account
2. 进入「Certificates, Identifiers & Profiles」
3. 点击「Devices」→「+」
4. 输入设备名称和 UDID
5. 点击「Continue」→「Register」

### Step 3: 创建 Ad Hoc 描述文件

1. 在 Developer Portal 点击「Profiles」→「+」
2. 选择「Ad Hoc」
3. 选择 App ID
4. 选择证书
5. 选择要包含的设备
6. 下载描述文件

### Step 4: 打包 Ad Hoc IPA

在 Xcode：
1. `Product` → `Archive`
2. 选择 Archive → `Distribute App`
3. 选择「Ad Hoc」
4. 选择刚才创建的描述文件
5. 导出 IPA

### Step 5: 分发给用户

**方法 1：使用第三方分发平台**
- 蒲公英：https://www.pgyer.com
- Fir.im：https://fir.im
- Diawi：https://www.diawi.com

上传 IPA → 获取分享链接 → 发送给测试员

**方法 2：通过邮件/网盘**
1. 将 IPA 发送给测试员
2. 测试员需要使用 iTunes/Apple Configurator 安装
3. 或者使用 Testflight 类似的企业工具

---

## 🏢 企业分发步骤

⚠️ **重要：仅限公司内部员工使用，违规会被 Apple 取消账号！**

### 前置条件
- Apple Developer Enterprise Program 账号（$299/年）
- 公司必须有 D-U-N-S Number

### 步骤
1. 创建 Enterprise Distribution 证书
2. 创建 In-House 描述文件（Provisioning Profile）
3. 使用该描述文件打包
4. 部署到公司内部服务器
5. 员工通过 OTA（Over-The-Air）安装

**安装方式：**
- 通过 Safari 访问你的分发页面
- 点击安装链接
- 系统会提示安装企业应用

---

## 📋 检查清单

### 打包前检查

- [ ] 修改 Bundle ID（如果需要）
- [ ] 更新版本号（Version & Build）
- [ ] 设置正确的 Signing & Capabilities
- [ ] 配置正确的 API Base URL（生产环境）
- [ ] 移除调试代码和 print 语句
- [ ] 测试所有核心功能
- [ ] 检查隐私权限描述（Info.plist）
- [ ] 添加 App Icon（所有尺寸）
- [ ] 配置 Launch Screen

### TestFlight 检查

- [ ] 填写「测试信息」
- [ ] 提供测试账号（如果需要登录）
- [ ] 添加 Beta 测试说明
- [ ] 设置自动分发新版本
- [ ] 配置测试组

### 隐私合规

- [ ] 在 App Store Connect 填写「隐私详情」
- [ ] 说明收集的数据类型和用途
- [ ] 提供隐私政策链接
- [ ] 说明是否有第三方SDK

---

## 🔧 常见问题

### Q: Archive 时报错 "Code signing error"
**A:**
1. 检查 Signing & Capabilities 配置
2. 在 Keychain 中检查证书是否有效
3. 重新下载 Provisioning Profile
4. 清理项目：`Product` → `Clean Build Folder`

### Q: TestFlight 上传后提示 "Invalid Binary"
**A:**
1. 检查 Info.plist 中的权限描述是否完整
2. 确保使用了正确的证书和描述文件
3. 检查是否有缺失的图标尺寸
4. 查看 App Store Connect 中的具体错误信息

### Q: 测试员无法安装 TestFlight 版本
**A:**
1. 确认测试员的设备系统版本符合最低要求
2. 确认测试员已被添加到测试组
3. 让测试员检查邮件垃圾箱
4. 尝试重新发送邀请

### Q: Ad Hoc 安装时提示 "无法安装"
**A:**
1. 确认设备 UDID 已注册
2. 确认描述文件包含了该设备
3. 确认证书未过期
4. 让用户删除旧版本后重新安装

---

## 📚 相关资源

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [TestFlight Beta Testing](https://developer.apple.com/testflight/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Xcode Archive and Upload Guide](https://help.apple.com/xcode/mac/current/#/dev442d7f2ca)

---

## 💡 推荐流程

根据你的需求选择：

1. **小规模测试（< 10 人）**
   ```
   Ad Hoc 分发 + 蒲公英/Fir.im
   ```

2. **中等规模测试（10-100 人）**
   ```
   TestFlight 内部测试
   ```

3. **大规模测试（> 100 人）**
   ```
   TestFlight 外部测试
   ```

4. **准备上架**
   ```
   TestFlight 外部测试 → App Store 提审
   ```

5. **企业内部应用**
   ```
   Enterprise 分发（需要 Enterprise 账号）
   ```

---

## 快速开始（TestFlight）

最简单的开始方式：

```bash
# 1. 在 Xcode 中配置 Signing
# 2. 选择 Product → Archive
# 3. 上传到 App Store Connect
# 4. 在 TestFlight 中添加测试员
# 5. 分享测试链接
```

完成！🎉

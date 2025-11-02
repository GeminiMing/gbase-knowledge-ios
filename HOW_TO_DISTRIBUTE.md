# 分享 iOS App 给其他人使用 🚀

## 📱 最简单的方式：使用第三方分发平台

如果你只是想快速让几个人测试，推荐使用：

### 🥇 推荐：蒲公英（pgyer.com）

**步骤：**

1. **打开 Xcode**
2. **选择设备为 "Any iOS Device"**
   - 在 Xcode 顶部工具栏，点击设备选择器
   - 选择 "Any iOS Device (arm64)"

3. **创建 Archive**
   - 菜单：`Product` → `Archive`
   - 等待编译完成（约 2-5 分钟）

4. **导出 IPA**
   - Archive 完成后会自动打开 Organizer
   - 选择刚创建的 Archive
   - 点击 "Distribute App"
   - 选择 "Ad Hoc"
   - 点击 "Next" → "Automatically manage signing"
   - 点击 "Export"
   - 选择保存位置

5. **上传到蒲公英**
   - 访问：https://www.pgyer.com
   - 注册/登录
   - 点击 "上传应用"
   - 选择刚导出的 `.ipa` 文件
   - 上传完成后会得到一个分享链接和二维码

6. **分享给测试用户**
   - 复制分享链接发给用户
   - 或者让用户扫描二维码
   - 用户在手机Safari浏览器中打开链接
   - 点击"安装"

**注意事项：**
- ⚠️ 用户的设备 UDID 需要提前注册到你的开发者账号中（最多 100 台设备）
- ⚠️ 首次安装需要在"设置 → 通用 → VPN与设备管理"中信任企业证书

---

## 🏆 官方推荐：TestFlight（适合大规模测试）

如果你有 Apple Developer 账号（$99/年），TestFlight 是最好的选择：

### 优点
- ✅ 最多 10,000 名测试员
- ✅ 无需用户提供 UDID
- ✅ 用户可以直接从 App Store 下载 TestFlight
- ✅ 自动推送更新
- ✅ 收集崩溃日志

### 步骤

1. **在 App Store Connect 创建 App**
   - 访问：https://appstoreconnect.apple.com
   - 点击 "我的 App" → "+" → "新建 App"
   - 填写 App 信息

2. **在 Xcode 中上传**
   - `Product` → `Archive`
   - 选择 Archive → "Distribute App"
   - 选择 "App Store Connect"
   - 点击 "Upload"
   - 等待处理完成（约 5-30 分钟）

3. **配置 TestFlight**
   - 在 App Store Connect 中选择你的 App
   - 点击 "TestFlight" 标签
   - 添加测试员邮箱
   - TestFlight 会自动发送邀请邮件

4. **测试员安装**
   - 测试员在 App Store 下载 "TestFlight" App
   - 打开邀请邮件中的链接
   - 在 TestFlight 中安装你的 App

---

## 🛠️ 使用命令行脚本（自动化）

我已经为你创建了自动化脚本，使用方法：

```bash
cd /Users/apple/code/felo/flutter/GBaseKnowledgeApp

# Ad Hoc 分发（蒲公英等平台）
./distribute.sh ad-hoc

# TestFlight/App Store 分发
./distribute.sh testflight
```

脚本会自动：
1. ✅ 清理旧的构建文件
2. ✅ 创建 Archive
3. ✅ 导出 IPA
4. ✅ 显示 IPA 路径和大小
5. ✅ 提供后续上传步骤

---

## 📝 对比表格

| 方式 | 人数限制 | 需要 UDID | 费用 | 安装难度 | 推荐场景 |
|------|---------|----------|------|---------|---------|
| 蒲公英/Fir | 无限制* | ✅ 需要 | 免费** | ⭐⭐⭐ | 快速测试 |
| TestFlight | 10,000 | ❌ 不需要 | $99/年 | ⭐⭐⭐⭐⭐ | 正式测试 |
| Ad Hoc | 100 | ✅ 需要 | $99/年 | ⭐⭐ | 小规模测试 |
| Enterprise | 无限制 | ❌ 不需要 | $299/年 | ⭐⭐⭐⭐ | 企业内部 |

*注：免费账号有限制，付费账号无限制
**注：有上传次数/空间限制，付费可解除

---

## 🎯 快速开始（最简单）

**如果你只是想让几个朋友测试：**

1. 打开 Xcode
2. `Product` → `Archive`
3. 导出 Ad Hoc IPA
4. 上传到 https://www.pgyer.com
5. 分享链接给朋友

**如果你要正式发布测试版：**

1. 在 https://appstoreconnect.apple.com 创建 App
2. 在 Xcode 中 `Product` → `Archive` → Upload
3. 在 App Store Connect 的 TestFlight 中添加测试员
4. 测试员通过 TestFlight App 安装

---

## 📚 详细文档

查看完整的分发指南：
- [DISTRIBUTION_GUIDE.md](./DISTRIBUTION_GUIDE.md) - 详细的分发步骤和说明

---

## ❓ 常见问题

**Q: 我没有 Apple Developer 账号，怎么办？**
A: 使用蒲公英等第三方平台，但需要收集测试设备的 UDID（最多 100 台）。

**Q: 如何获取设备 UDID？**
A:
- 方法1：连接 iTunes/Finder，点击序列号显示 UDID
- 方法2：让用户访问 https://get.udid.io

**Q: TestFlight 需要审核吗？**
A: 内部测试（最多 100 人）无需审核。外部测试首次提交需要审核（1-2天），后续更新无需审核。

**Q: 蒲公英安装时提示"无法安装"？**
A: 确保设备 UDID 已添加到开发者账号中，并且重新打包了包含该设备的版本。

---

## 🎉 推荐流程

**新手/快速测试：**
```
Xcode Archive → 导出 Ad Hoc IPA → 上传蒲公英 → 分享链接
```

**专业/大规模测试：**
```
Xcode Archive → 上传 App Store Connect → TestFlight 配置 → 邀请测试员
```

**准备正式发布：**
```
TestFlight 测试 → 收集反馈 → 修复问题 → App Store 提审
```

---

需要帮助？查看详细文档或联系我！

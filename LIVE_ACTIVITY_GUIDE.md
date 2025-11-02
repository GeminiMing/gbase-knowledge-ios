# iOS 后台录音功能实现说明

## ✅ 当前状态

### 已实现功能
- **后台录音支持** ✅ 完全正常
  - 使用 `AVAudioSession.Category.playAndRecord` + `UIBackgroundModes: audio`
  - 支持无限时长后台录音
  - 自动恢复机制

### Live Activity（灵动岛）功能
- **代码已准备** ⚠️ 需手动启用
  - 文件已创建但未添加到 Xcode 项目
  - 需要在 Xcode 中手动添加文件后才能使用

---

## 🔧 当前配置

### AudioRecorderService 关键配置

音频会话配置 ([AudioRecorderService.swift:128](GBaseKnowledgeApp/Services/AudioRecorderService.swift#L128))：
```swift
try session.setCategory(.playAndRecord, mode: .default, options: [
    .defaultToSpeaker,
    .allowBluetooth,
    .allowBluetoothA2DP
])
```

### 项目配置
- ✅ `INFOPLIST_KEY_UIBackgroundModes` = audio
- ✅ `INFOPLIST_KEY_NSSupportsLiveActivities` = YES
- ✅ `INFOPLIST_KEY_NSMicrophoneUsageDescription` = "录音上传会议需要麦克风访问权限"

---

## 📱 真机测试说明

### 后台录音测试步骤
1. 在真机上运行应用
2. 开始录音
3. 按 Home 键切换到其他应用
4. 等待 1-2 分钟
5. 返回应用，检查录音是否持续进行

### 常见问题

#### Q: 为什么模拟器可以后台录音，但真机不行？
A: 模拟器不会严格执行后台限制，真机会。真机需要：
- ✅ 正确配置 `UIBackgroundModes: audio`
- ✅ 使用 `.playAndRecord` 或 `.record` category
- ✅ 音频会话必须在录音开始时激活
- ❌ 不能使用 `.mixWithOthers` 选项（会导致暂停）

#### Q: 为什么会出现 OSStatus 错误 -50？
A: 这是音频会话配置参数不兼容导致的。已修复：
- `.record` category 不支持 `.defaultToSpeaker` 选项
- 现在统一使用 `.playAndRecord` category（兼容性最好）

---

## 🚀 如何启用 Live Activity（灵动岛）

### 第一步：在 Xcode 中添加文件

1. 打开 Xcode 项目：`GBaseKnowledgeApp.xcodeproj`
2. 选中项目导航器中的 `Services` 文件夹
3. 右键点击 → "Add Files to GBaseKnowledgeApp..."
4. 选择：`GBaseKnowledgeApp/Services/RecordingLiveActivity.swift`
5. 勾选 "Copy items if needed" 和项目 target
6. 点击 "Add"

7. 同样方式添加：
   - `GBaseKnowledgeApp/Presentation/Components/RecordingLiveActivityView.swift`

### 第二步：启用 Live Activity 代码

在 [AudioRecorderService.swift](GBaseKnowledgeApp/Services/AudioRecorderService.swift) 中，取消注释以下代码：

**录音开始时**（第 72-74 行）：
```swift
// 启动 Live Activity（iOS 16.1+）
if #available(iOS 16.1, *) {
    RecordingLiveActivityService.shared.start(title: "语音录音")
}
```

**录音停止时**（第 91-93 行）：
```swift
// 结束 Live Activity（iOS 16.1+）
if #available(iOS 16.1, *) {
    RecordingLiveActivityService.shared.finish(duration: finalDuration)
}
```

**取消录音时**（第 111-113 行）：
```swift
// 停止 Live Activity（iOS 16.1+）
if #available(iOS 16.1, *) {
    RecordingLiveActivityService.shared.stop()
}
```

**更新时长时**（第 400-402 行）：
```swift
// 更新 Live Activity（iOS 16.1+）
if #available(iOS 16.1, *) {
    RecordingLiveActivityService.shared.update(duration: duration, level: level)
}
```

### 第三步：重新编译运行

1. Clean Build Folder (Cmd + Shift + K)
2. 重新编译项目 (Cmd + B)
3. 在真机上运行测试

---

## 🎯 Live Activity 效果

启用后，录音时会在以下位置显示：

### iPhone 14 Pro 及以上（灵动岛）
- **最小视图**：红色闪烁圆点
- **紧凑视图**：红点 + 录音时长（如 "1:23"）
- **展开视图**：标题 + 时长 + 音量指示器

### 所有 iOS 16.1+ 设备（锁屏）
- 锁屏界面显示完整录音信息
- 实时更新时长和音量
- 点击可返回应用

---

## 📝 使用方法

### 自动使用（推荐）
`AudioRecorderService` 会自动管理后台录音：

```swift
let audioRecorder = AudioRecorderService()

// 开始录音 - 自动配置后台支持
try audioRecorder.startRecording(to: fileURL)

// 录音会自动在后台继续
// 无需额外代码

// 停止录音
audioRecorder.stopRecording()
```

### 检查后台状态
查看 Xcode 控制台输出：
- `✅ 音频会话配置成功` - 配置正常
- `✅ 音频会话激活成功 - 支持后台录音` - 后台支持已启用
- `📱 应用进入后台，检查录音状态...` - 应用进入后台
- `✅ 录音器仍在运行` - 后台录音正常

---

## ⚠️ 重要提示

### 确保后台录音正常工作
1. **不要使用 `.mixWithOthers` 选项** - 会导致后台暂停
2. **音频会话必须在录音前激活** - 已自动处理
3. **使用 `.playAndRecord` category** - 兼容性最好
4. **真机测试必需** - 模拟器行为不准确

### Live Activity 注意事项
1. **需要 iOS 16.1+**
2. **灵动岛需要 iPhone 14 Pro+**
3. **锁屏显示支持所有 iOS 16.1+ 设备**
4. **用户可以在系统设置中禁用 Live Activity**

---

## 🔍 故障排查

### 后台录音不工作
1. 检查 Xcode 控制台是否有错误
2. 确认 `UIBackgroundModes: audio` 已配置
3. 检查音频会话是否激活成功
4. 确认没有使用 `.mixWithOthers` 选项

### Live Activity 不显示
1. 确认文件已添加到 Xcode 项目
2. 检查代码注释是否已取消
3. 确认设备支持（iOS 16.1+）
4. 检查系统设置中 Live Activity 是否启用

---

## 📚 相关文档

- [AVAudioSession - Apple Developer](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [Background Execution - Apple Developer](https://developer.apple.com/documentation/avfoundation/media_playback/configuring_your_app_for_media_playback)
- [ActivityKit - Apple Developer](https://developer.apple.com/documentation/activitykit)


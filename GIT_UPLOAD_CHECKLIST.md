# Git 上传准备清单

## ✅ 已完成的准备工作

1. ✅ **创建了 .gitignore 文件**
   - 忽略 Xcode 用户数据
   - 忽略构建产物
   - 忽略系统文件

2. ✅ **创建了项目结构文档**
   - `PROJECT_STRUCTURE.md` - 详细的目录结构说明

## ⚠️ 需要处理的重复文件

### 本地化文件重复
**当前状态**：
- `GBaseKnowledgeApp/Base.lproj/` ✅ 存在
- `GBaseKnowledgeApp/en.lproj/` ✅ 存在
- `GBaseKnowledgeApp/ja.lproj/` ✅ 存在
- `GBaseKnowledgeApp/zh-Hans.lproj/` ✅ 存在
- `GBaseKnowledgeApp/Resources/Base.lproj/` ✅ 存在
- `GBaseKnowledgeApp/Resources/en.lproj/` ✅ 存在
- `GBaseKnowledgeApp/Resources/ja.lproj/` ✅ 存在
- `GBaseKnowledgeApp/Resources/zh-Hans.lproj/` ✅ 存在

**建议**：
- **保留** `Resources/` 下的本地化文件（iOS 标准位置）
- **删除** `GBaseKnowledgeApp/` 下直接放置的 `.lproj` 文件夹

**执行命令**：
```bash
cd GBaseKnowledgeApp
rm -rf GBaseKnowledgeApp/Base.lproj
rm -rf GBaseKnowledgeApp/en.lproj
rm -rf GBaseKnowledgeApp/ja.lproj
rm -rf GBaseKnowledgeApp/zh-Hans.lproj
```

## ⚠️ realm-swift-master 处理（157MB）

**当前状态**：项目引用了本地路径 `../realm-swift-master`

**建议方案 A（推荐）**：使用远程 SPM 依赖
1. 在 Xcode 中移除本地包引用
2. 添加远程包：`https://github.com/realm/realm-swift.git`
3. 版本：使用与当前相同的版本（14.14.0）

**建议方案 B**：作为 Git Submodule
```bash
cd GBaseKnowledgeApp
git submodule add https://github.com/realm/realm-swift.git realm-swift-master
```

**建议方案 C**：暂时不提交（如果使用方案 A）
- 在 `.gitignore` 中添加 `realm-swift-master/`
- 团队成员需要时自行克隆

## 📝 文档文件处理

- ✅ `README.md` - **保留**（项目说明）
- ⚠️ `LOCALIZATION_DEBUG.md` - **删除或移动到 docs/**
- ⚠️ `REALM_DEPENDENCY_FIX.md` - **删除或移动到 docs/**
- ✅ `PROJECT_STRUCTURE.md` - **保留**（目录结构说明）

## 🚀 上传步骤

### 步骤 1：清理重复文件
```bash
cd /Users/apple/code/felo/flutter/GBaseKnowledgeApp

# 删除重复的本地化文件夹
rm -rf GBaseKnowledgeApp/Base.lproj
rm -rf GBaseKnowledgeApp/en.lproj
rm -rf GBaseKnowledgeApp/ja.lproj
rm -rf GBaseKnowledgeApp/zh-Hans.lproj

# 可选：删除调试文档
rm LOCALIZATION_DEBUG.md REALM_DEPENDENCY_FIX.md
```

### 步骤 2：检查 Git 状态
```bash
git status
```

### 步骤 3：添加文件
```bash
# 添加 .gitignore
git add .gitignore

# 添加项目文件
git add GBaseKnowledgeApp/
git add GBaseKnowledgeApp.xcodeproj/

# 添加文档
git add README.md PROJECT_STRUCTURE.md
```

### 步骤 4：提交
```bash
git commit -m "feat: Initial commit - GBase Knowledge App

- iOS app for meeting recording and knowledge management
- Supports Chinese, English, Japanese localization
- Uses Realm for local storage
- Clean Architecture with MVVM pattern"
```

### 步骤 5：推送到远程
```bash
# 添加远程仓库（如果还没有）
git remote add origin <your-repo-url>

# 推送
git push -u origin main
# 或
git push -u origin master
```

## 📊 项目大小估算

- **应用代码**：~840KB
- **项目文件**：~72KB
- **资源文件**：~100KB
- **文档**：~20KB
- **总计（不含 realm-swift）**：~1MB

## ✅ 最终检查清单

- [ ] 清理了重复的本地化文件
- [ ] 处理了 realm-swift-master（选择方案 A、B 或 C）
- [ ] 删除了临时调试文档
- [ ] 检查了 `.gitignore` 配置
- [ ] 检查了敏感信息（API 密钥、Token 等）
- [ ] 运行了 `git status` 确认要提交的文件
- [ ] 提交并推送到远程仓库

## 🔒 安全注意事项

上传前请检查以下文件是否包含敏感信息：
- `Data/API/APIConfiguration.swift` - API 配置
- `Services/KeychainTokenStore.swift` - Token 存储逻辑
- 任何包含硬编码密钥的文件

如果有敏感信息，请：
1. 使用环境变量
2. 使用配置文件（加入 .gitignore）
3. 使用 Xcode 的 Build Configuration


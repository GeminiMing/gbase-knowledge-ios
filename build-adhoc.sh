#!/bin/bash

# Ad Hoc 打包脚本 - 手动版本
# 使用方法: ./build-adhoc.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_FILE="GBase.xcodeproj"
SCHEME="GBase"
CONFIGURATION="Release"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/GBase.xcarchive"
EXPORT_PATH="$BUILD_DIR/Export-AdHoc"

echo -e "${GREEN}=== Ad Hoc 打包脚本 ===${NC}"
echo "项目目录: $PROJECT_DIR"
echo ""

# 清理旧的构建文件
echo -e "${YELLOW}1. 清理旧的构建文件...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$EXPORT_PATH"

# 创建 ExportOptions.plist
echo -e "${YELLOW}2. 创建 ExportOptions.plist...${NC}"
cat > "$BUILD_DIR/ExportOptions-AdHoc.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <false/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF

# 创建 Archive
echo -e "${YELLOW}3. 创建 Archive...${NC}"
echo "这可能需要几分钟时间，请耐心等待..."
xcodebuild -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk iphoneos \
    -archivePath "$ARCHIVE_PATH" \
    clean archive \
    CODE_SIGN_IDENTITY="Apple Development" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=ZDCRSX5D6W \
    2>&1 | tee "$BUILD_DIR/archive.log"

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}错误: Archive 创建失败${NC}"
    echo "请查看日志: $BUILD_DIR/archive.log"
    exit 1
fi

echo -e "${GREEN}✓ Archive 创建成功${NC}"

# 导出 IPA
echo -e "${YELLOW}4. 导出 IPA...${NC}"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions-AdHoc.plist" \
    2>&1 | tee "$BUILD_DIR/export.log"

IPA_PATH="$EXPORT_PATH/GBase.ipa"

if [ ! -f "$IPA_PATH" ]; then
    echo -e "${RED}错误: IPA 导出失败${NC}"
    echo "请查看日志: $BUILD_DIR/export.log"
    exit 1
fi

IPA_SIZE=$(du -h "$IPA_PATH" | cut -f1)
echo ""
echo -e "${GREEN}=== 打包成功 ===${NC}"
echo "IPA 路径: $IPA_PATH"
echo "IPA 大小: $IPA_SIZE"
echo ""
echo -e "${YELLOW}下一步：${NC}"
echo "1. 访问 https://www.pgyer.com"
echo "2. 登录/注册账号"
echo "3. 点击 '上传应用'"
echo "4. 选择文件: $IPA_PATH"
echo "5. 上传完成后获取分享链接"
echo ""
echo -e "${GREEN}完成！${NC}"




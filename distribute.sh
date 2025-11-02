#!/bin/bash

# GBase Knowledge App 分发脚本
# 使用方法: ./distribute.sh [ad-hoc|app-store|testflight]

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEME="GBaseKnowledgeApp"
CONFIGURATION="Release"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/${SCHEME}.xcarchive"
EXPORT_PATH="$BUILD_DIR/Export"

# 检查参数
METHOD=${1:-"ad-hoc"}

if [[ ! "$METHOD" =~ ^(ad-hoc|app-store|testflight)$ ]]; then
    echo -e "${RED}错误: 无效的分发方式: $METHOD${NC}"
    echo "使用方法: ./distribute.sh [ad-hoc|app-store|testflight]"
    exit 1
fi

echo -e "${GREEN}=== GBase Knowledge App 分发工具 ===${NC}"
echo "分发方式: $METHOD"
echo "项目目录: $PROJECT_DIR"
echo ""

# 清理旧的构建文件
echo -e "${YELLOW}1. 清理旧的构建文件...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 创建 Archive
echo -e "${YELLOW}2. 创建 Archive...${NC}"
xcodebuild -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk iphoneos \
    -archivePath "$ARCHIVE_PATH" \
    clean archive \
    | xcpretty || xcodebuild -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -sdk iphoneos \
        -archivePath "$ARCHIVE_PATH" \
        clean archive

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}错误: Archive 创建失败${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Archive 创建成功${NC}"

# 根据分发方式设置 ExportOptions
echo -e "${YELLOW}3. 准备导出配置...${NC}"

if [ "$METHOD" == "testflight" ]; then
    METHOD="app-store"
fi

# 创建临时的 ExportOptions.plist
TEMP_EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
cat > "$TEMP_EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$METHOD</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF

# 导出 IPA
echo -e "${YELLOW}4. 导出 IPA...${NC}"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$TEMP_EXPORT_OPTIONS" \
    | xcpretty || xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$TEMP_EXPORT_OPTIONS"

IPA_PATH="$EXPORT_PATH/${SCHEME}.ipa"

if [ ! -f "$IPA_PATH" ]; then
    echo -e "${RED}错误: IPA 导出失败${NC}"
    exit 1
fi

echo -e "${GREEN}✓ IPA 导出成功${NC}"

# 显示 IPA 信息
IPA_SIZE=$(du -h "$IPA_PATH" | cut -f1)
echo ""
echo -e "${GREEN}=== 构建成功 ===${NC}"
echo "IPA 路径: $IPA_PATH"
echo "IPA 大小: $IPA_SIZE"
echo "分发方式: $METHOD"
echo ""

# 根据分发方式提供后续步骤
case "$METHOD" in
    "ad-hoc")
        echo -e "${YELLOW}后续步骤（Ad Hoc 分发）:${NC}"
        echo "1. 将 IPA 上传到分发平台:"
        echo "   - 蒲公英: https://www.pgyer.com"
        echo "   - Fir.im: https://fir.im"
        echo "   - Diawi: https://www.diawi.com"
        echo ""
        echo "2. 或者使用以下命令直接上传到蒲公英:"
        echo "   curl -F 'file=@$IPA_PATH' \\"
        echo "        -F '_api_key=YOUR_API_KEY' \\"
        echo "        https://www.pgyer.com/apiv2/app/upload"
        ;;

    "app-store")
        echo -e "${YELLOW}后续步骤（App Store/TestFlight）:${NC}"
        echo "1. 使用 Xcode Organizer 上传:"
        echo "   - 打开 Xcode"
        echo "   - Window → Organizer"
        echo "   - 选择 Archive → Distribute App"
        echo ""
        echo "2. 或者使用 altool 命令行上传:"
        echo "   xcrun altool --upload-app \\"
        echo "        --type ios \\"
        echo "        --file '$IPA_PATH' \\"
        echo "        --username 'your-apple-id@email.com' \\"
        echo "        --password 'your-app-specific-password'"
        echo ""
        echo "3. 上传后在 App Store Connect 中配置 TestFlight"
        ;;
esac

echo ""
echo -e "${GREEN}完成！${NC}"

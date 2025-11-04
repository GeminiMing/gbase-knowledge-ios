#!/bin/bash

# GBase Knowledge App 开发分发脚本（使用免费 Apple ID）
# 使用方法: ./distribute-dev.sh

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEME="GBaseKnowledgeApp"
CONFIGURATION="Debug"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/${SCHEME}.xcarchive"
EXPORT_PATH="$BUILD_DIR/Export-Dev"

echo -e "${GREEN}=== GBase Knowledge App 开发分发工具 ===${NC}"
echo -e "${YELLOW}注意: 此脚本使用 Development 签名，适用于免费 Apple ID${NC}"
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
    clean archive

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}错误: Archive 创建失败${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Archive 创建成功${NC}"

# 创建 Development ExportOptions.plist
echo -e "${YELLOW}3. 准备导出配置 (Development)...${NC}"

TEMP_EXPORT_OPTIONS="$BUILD_DIR/ExportOptions-Dev.plist"
cat > "$TEMP_EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
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
echo "分发方式: Development (免费 Apple ID)"
echo ""

echo -e "${YELLOW}后续步骤:${NC}"
echo "1. 将 IPA 上传到分发平台:"
echo "   - 蒲公英: https://www.pgyer.com"
echo "   - Fir.im: https://fir.im"
echo ""
echo "2. 上传后获取分享链接，发送给测试用户"
echo ""
echo "3. 测试用户需要:"
echo "   - 在 Safari 浏览器中打开链接"
echo "   - 点击安装"
echo "   - 在设置中信任开发者证书"
echo ""

echo -e "${GREEN}完成！${NC}"

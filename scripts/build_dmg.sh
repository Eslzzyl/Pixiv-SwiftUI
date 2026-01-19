#! /bin/zsh

set -e

# --- 配置变量 ---
PROJECT_NAME="Pixiv-SwiftUI"
SCHEME_NAME="Pixiv-SwiftUI"
CONFIG="Release"
BUILD_DIR="build"
DMG_NAME="Pixiv-SwiftUI"

# 1. 清理并编译
echo "开始编译 macOS 应用..."
xcodebuild clean build \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME_NAME}" \
    -sdk macosx \
    -configuration "${CONFIG}" \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGN_IDENTITY="-"  # Ad-hoc 签名，允许在本地运行

# 2. 创建目录
echo "创建打包目录..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/dmg_root"

# 3. 复制编译好的 .app (寻找 Release 产物)
# 注意：macOS 的路径通常在 Release 目录下，没有 -iphoneos 后缀
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "${PROJECT_NAME}.app" -type d -path "*/Build/Products/${CONFIG}/*" | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "错误：找不到 macOS 的构建产物"
    exit 1
fi

echo "找到构建产物: $APP_PATH"
cp -r "$APP_PATH" "${BUILD_DIR}/dmg_root/"

# 4. 创建 Applications 符号链接 (让 DMG 看起来更专业)
ln -s /Applications "${BUILD_DIR}/dmg_root/Applications"

# 5. 打包成 DMG
echo "正在生成 DMG 文件..."
# 如果已存在旧的 dmg 则删除
if [ -f "${BUILD_DIR}/${DMG_NAME}.dmg" ]; then
    rm "${BUILD_DIR}/${DMG_NAME}.dmg"
fi

hdiutil create -volname "${PROJECT_NAME} Installer" \
               -srcfolder "${BUILD_DIR}/dmg_root" \
               -ov -format UDZO \
               "${BUILD_DIR}/${DMG_NAME}.dmg"

echo "--------------------------------------"
echo "DMG 打包完成: ${BUILD_DIR}/${DMG_NAME}.dmg"
echo "--------------------------------------"

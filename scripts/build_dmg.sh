#! /bin/zsh

set -e

VERBOSE=false
SHOW_HELP=false
CLEAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            SHOW_HELP=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

if [ "$SHOW_HELP" = true ]; then
    echo "用法: build_dmg.sh [-v|--verbose] [--clean] [-h|--help]"
    echo ""
    echo "选项:"
    echo "  -v, --verbose  显示详细输出"
    echo "  --clean        清理后构建（默认增量编译）"
    echo "  -h, --help     显示帮助信息"
    exit 0
fi

PROJECT_NAME="Pixiv-SwiftUI"
SCHEME_NAME="Pixiv-SwiftUI"
CONFIG="Release"
BUILD_DIR="build"
DMG_NAME="Pixiv-SwiftUI"
ARCHS=("arm64" "x86_64")

BUILD_OUTPUT="/dev/null"
if [ "$VERBOSE" = true ]; then
    BUILD_OUTPUT="/dev/stdout"
fi

JOBS=$(sysctl -n hw.ncpu)

echo "=========================================="
echo "开始构建 macOS DMG 包"
echo "架构: ${ARCHS[*]}"
echo "模式: $([ "$CLEAN" = true ] && echo "全量编译" || echo "增量编译")"
echo "=========================================="

for ARCH in "${ARCHS[@]}"; do
    echo ""
    echo "=========================================="
    echo "开始构建 ${ARCH} 架构"
    echo "=========================================="

    if [ "$CLEAN" = true ]; then
        xcodebuild clean build \
            -project "${PROJECT_NAME}.xcodeproj" \
            -scheme "${SCHEME_NAME}" \
            -sdk macosx \
            -configuration "${CONFIG}" \
            -destination "platform=macOS,arch=${ARCH}" \
            ARCHS="${ARCH}" \
            CODE_SIGNING_ALLOWED=YES \
            CODE_SIGNING_REQUIRED=YES \
            CODE_SIGN_IDENTITY="-" \
            -jobs $JOBS \
            2>&1 | grep -v "^\*" | grep -v "^Build" | grep -v "^CompileC" | grep -v "^Ld " | grep -v "^ProcessInfoPlistFile" | grep -v "^CopyStringsFile" | grep -v "^CpResource" | grep -v "^Touch" | grep -v "^GenerateDSYMFile" | grep -v "^CodeSign" | grep -v "^CopyFiles" > "$BUILD_OUTPUT"
    else
        xcodebuild build \
            -project "${PROJECT_NAME}.xcodeproj" \
            -scheme "${SCHEME_NAME}" \
            -sdk macosx \
            -configuration "${CONFIG}" \
            -destination "platform=macOS,arch=${ARCH}" \
            ARCHS="${ARCH}" \
            CODE_SIGNING_ALLOWED=YES \
            CODE_SIGNING_REQUIRED=YES \
            CODE_SIGN_IDENTITY="-" \
            -jobs $JOBS \
            2>&1 | grep -v "^\*" | grep -v "^Build" | grep -v "^CompileC" | grep -v "^Ld " | grep -v "^ProcessInfoPlistFile" | grep -v "^CopyStringsFile" | grep -v "^CpResource" | grep -v "^Touch" | grep -v "^GenerateDSYMFile" | grep -v "^CodeSign" | grep -v "^CopyFiles" > "$BUILD_OUTPUT"
    fi

echo "编译完成，开始打包..."

mkdir -p "${BUILD_DIR}/dmg_root_${ARCH}"

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "${PROJECT_NAME}.app" -type d -path "*/Build/Products/${CONFIG}/*" | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "错误：找不到 ${ARCH} 架构的构建产物"
    exit 1
fi

APP_BINARY="${APP_PATH}/Contents/MacOS/${PROJECT_NAME}"
if [ ! -f "$APP_BINARY" ]; then
    echo "错误：找不到可执行文件: $APP_BINARY"
    exit 1
fi

APP_ARCH=$(file "$APP_BINARY" | grep -oE 'arm64|x86_64' | head -n 1)
if [ "$APP_ARCH" != "$ARCH" ]; then
    echo "错误：构建产物架构不匹配，期望 ${ARCH}，实际 ${APP_ARCH}"
    exit 1
fi

echo "找到构建产物: $APP_PATH (架构: ${APP_ARCH})"
cp -r "$APP_PATH" "${BUILD_DIR}/dmg_root_${ARCH}/"

ln -sf /Applications "${BUILD_DIR}/dmg_root_${ARCH}/Applications"

if [ -f "${BUILD_DIR}/${DMG_NAME}-${ARCH}.dmg" ]; then
    rm "${BUILD_DIR}/${DMG_NAME}-${ARCH}.dmg"
fi

echo "正在生成 DMG 文件..."
hdiutil create -volname "${PROJECT_NAME} (${ARCH}) Installer" \
               -srcfolder "${BUILD_DIR}/dmg_root_${ARCH}" \
               -ov -format UDZO \
               "${BUILD_DIR}/${DMG_NAME}-${ARCH}.dmg" 2>/dev/null

echo "=========================================="
echo "DMG 打包完成: ${BUILD_DIR}/${DMG_NAME}-${ARCH}.dmg"
echo "=========================================="
done

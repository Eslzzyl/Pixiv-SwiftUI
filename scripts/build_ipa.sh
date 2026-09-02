#! /bin/zsh

set -e
setopt pipefail

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
    echo "用法: build_ipa.sh [-v|--verbose] [--clean] [-h|--help]"
    echo ""
    echo "选项:"
    echo "  -v, --verbose  显示详细输出"
    echo "  --clean        清理后构建（默认增量编译）"
    echo "  -h, --help     显示帮助信息"
    exit 0
fi

echo "=========================================="
echo "开始构建 iOS IPA 包"
echo "模式: $([ "$CLEAN" = true ] && echo "全量编译" || echo "增量编译")"
echo "=========================================="

JOBS=$(sysctl -n hw.ncpu)
DERIVED_DATA_PATH="build/derived_data"
BUILD_LOG=$(mktemp -t pixiv-swiftui-ipa-build)
trap 'rm -f "$BUILD_LOG"' EXIT

# 确保 build 目录存在
mkdir -p build

XCODEBUILD_CMD=(
    xcodebuild
    -project Pixiv-SwiftUI.xcodeproj
    -scheme Pixiv-SwiftUI
    -sdk iphoneos
    -configuration Release
    -destination 'generic/platform=iOS'
    -derivedDataPath "$DERIVED_DATA_PATH"
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGN_IDENTITY=""
    -jobs "$JOBS"
)

echo "正在运行 xcodebuild (iOS)..."

if [ "$CLEAN" = true ]; then
    if "${XCODEBUILD_CMD[@]}" clean build > "$BUILD_LOG" 2>&1; then
        XCODEBUILD_STATUS=0
    else
        XCODEBUILD_STATUS=$?
    fi
else
    if "${XCODEBUILD_CMD[@]}" build > "$BUILD_LOG" 2>&1; then
        XCODEBUILD_STATUS=0
    else
        XCODEBUILD_STATUS=$?
    fi
fi

if [ "$XCODEBUILD_STATUS" -ne 0 ]; then
    echo "错误：xcodebuild (iOS) 失败，退出码: $XCODEBUILD_STATUS"
    echo "=========================================="
    cat "$BUILD_LOG"
    echo "=========================================="
    exit "$XCODEBUILD_STATUS"
fi

if [ "$VERBOSE" = true ]; then
    cat "$BUILD_LOG"
fi

echo "编译完成，开始打包..."

rm -rf build/Payload
mkdir -p build/Payload

APP_PATH=$(find "$DERIVED_DATA_PATH" -name "Pixiv-SwiftUI.app" -type d -path "*/Release-iphoneos/*" | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "错误：找不到 Release-iphoneos 的构建产物"
    echo "尝试搜索路径: $DERIVED_DATA_PATH"
    if [ -d "$DERIVED_DATA_PATH" ]; then
        echo "当前已存在的构建目录清单:"
        find "$DERIVED_DATA_PATH" -maxdepth 4 -type d
    else
        echo "构建目录不存在: $DERIVED_DATA_PATH"
    fi
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "错误：找到的路径不是目录: $APP_PATH"
    exit 1
fi

echo "找到构建产物: $APP_PATH"
cp -r "$APP_PATH" build/Payload/

if [ ! -f "build/Payload/Pixiv-SwiftUI.app/Pixiv-SwiftUI" ]; then
    echo "错误：复制后的 .app 中缺少可执行文件"
    exit 1
fi

cd build
rm -f Pixiv-SwiftUI.ipa
zip -9 -r Pixiv-SwiftUI.ipa Payload

cd ..

echo "=========================================="
echo "IPA 打包完成: build/Pixiv-SwiftUI.ipa"
echo "=========================================="

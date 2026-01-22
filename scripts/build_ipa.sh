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

BUILD_OUTPUT="/dev/null"
if [ "$VERBOSE" = true ]; then
    BUILD_OUTPUT="/dev/stdout"
fi

JOBS=$(sysctl -n hw.ncpu)

if [ "$CLEAN" = true ]; then
    xcodebuild clean build \
        -project Pixiv-SwiftUI.xcodeproj \
        -scheme Pixiv-SwiftUI \
        -sdk iphoneos \
        -configuration Release \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY="" \
        -jobs $JOBS \
        2>&1 | grep -v "^\*" | grep -v "^Build" | grep -v "^CompileC" | grep -v "^Ld " | grep -v "^ProcessInfoPlistFile" | grep -v "^CopyStringsFile" | grep -v "^CpResource" | grep -v "^Touch" | grep -v "^GenerateDSYMFile" | grep -v "^Archive" > "$BUILD_OUTPUT"
else
    xcodebuild build \
        -project Pixiv-SwiftUI.xcodeproj \
        -scheme Pixiv-SwiftUI \
        -sdk iphoneos \
        -configuration Release \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY="" \
        -jobs $JOBS \
        2>&1 | grep -v "^\*" | grep -v "^Build" | grep -v "^CompileC" | grep -v "^Ld " | grep -v "^ProcessInfoPlistFile" | grep -v "^CopyStringsFile" | grep -v "^CpResource" | grep -v "^Touch" | grep -v "^GenerateDSYMFile" | grep -v "^Archive" > "$BUILD_OUTPUT"
fi

echo "编译完成，开始打包..."

rm -rf build/Payload
mkdir -p build/Payload

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Pixiv-SwiftUI.app" -type d -path "*/Release-iphoneos/*" | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "错误：找不到 Release-iphoneos 的构建产物"
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

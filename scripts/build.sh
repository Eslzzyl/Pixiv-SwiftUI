#! /bin/zsh

set -e

VERBOSE=false
SHOW_HELP=false
IPA_ONLY=false
DMG_ONLY=false
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
        --ipa-only)
            IPA_ONLY=true
            shift
            ;;
        --dmg-only)
            DMG_ONLY=true
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
    echo "用法: build.sh [-v|--verbose] [-h|--help] [--ipa-only] [--dmg-only] [--clean]"
    echo ""
    echo "选项:"
    echo "  -v, --verbose     显示所有详细输出"
    echo "  --ipa-only        只构建 IPA"
    echo "  --dmg-only        只构建 DMG"
    echo "  --clean           清理后构建（默认增量编译）"
    echo "  -h, --help        显示帮助信息"
    echo ""
    echo "输出产物:"
    echo "  build/Pixiv-SwiftUI.ipa   (iOS)"
    echo "  build/Pixiv-SwiftUI.dmg   (macOS)"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$IPA_ONLY" = false ] && [ "$DMG_ONLY" = false ]; then
    IPA_ONLY=true
    DMG_ONLY=true
fi

BUILD_SUCCESS=true

if [ "$IPA_ONLY" = true ]; then
    echo ""
    echo "=========================================="
    echo ">>> 开始构建 iOS IPA"
    echo "=========================================="
    IPA_ARGS=""
    if [ "$VERBOSE" = true ]; then
        IPA_ARGS="$IPA_ARGS --verbose"
    fi
    if [ "$CLEAN" = true ]; then
        IPA_ARGS="$IPA_ARGS --clean"
    fi
    "${SCRIPT_DIR}/build_ipa.sh" $IPA_ARGS
    IPA_RESULT=$?
    if [ $IPA_RESULT -ne 0 ]; then
        BUILD_SUCCESS=false
        echo ">>> iOS IPA 构建失败"
    else
        echo ">>> iOS IPA 构建完成"
    fi
    echo ""
fi

if [ "$DMG_ONLY" = true ]; then
    echo "=========================================="
    echo ">>> 开始构建 macOS DMG"
    echo "=========================================="
    DMG_ARGS=""
    if [ "$VERBOSE" = true ]; then
        DMG_ARGS="$DMG_ARGS --verbose"
    fi
    if [ "$CLEAN" = true ]; then
        DMG_ARGS="$DMG_ARGS --clean"
    fi
    "${SCRIPT_DIR}/build_dmg.sh" $DMG_ARGS
    DMG_RESULT=$?
    if [ $DMG_RESULT -ne 0 ]; then
        BUILD_SUCCESS=false
        echo ">>> macOS DMG 构建失败"
    else
        echo ">>> macOS DMG 构建完成"
    fi
    echo ""
fi

echo "=========================================="
echo "构建结果汇总"
echo "=========================================="
if [ "$BUILD_SUCCESS" = true ]; then
    echo "全部构建成功"
    echo ""
    if [ "$IPA_ONLY" = true ]; then
        echo "  iOS IPA:  build/Pixiv-SwiftUI.ipa"
    fi
    if [ "$DMG_ONLY" = true ]; then
        echo "  macOS DMG: build/Pixiv-SwiftUI.dmg"
    fi
else
    echo "部分构建失败，请检查上方日志"
    exit 1
fi
echo "=========================================="

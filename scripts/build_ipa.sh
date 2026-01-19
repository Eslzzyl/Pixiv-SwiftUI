#! /bin/zsh

set -e

# 1. 清理并编译 (不进行签名)
xcodebuild clean build \
    -project Pixiv-SwiftUI.xcodeproj \
    -scheme Pixiv-SwiftUI \
    -sdk iphoneos \
    -configuration Release \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY=""

# 2. 创建目录
rm -rf build/Payload
mkdir -p build/Payload

# 3. 复制编译好的 .app (精确查找 Release-iphoneos 产物)
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

# 4. 验证 Payload 内容
if [ ! -f "build/Payload/Pixiv-SwiftUI.app/Pixiv-SwiftUI" ]; then
    echo "错误：复制后的 .app 中缺少可执行文件"
    exit 1
fi

# 5. 打包成 IPA
cd build
zip -r Pixiv-SwiftUI.ipa Payload

echo "IPA 打包完成: build/Pixiv-SwiftUI.ipa"
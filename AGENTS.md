# AGENTS.md

## 构建命令

### macOS 平台构建
```bash
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Debug -destination 'platform=macOS' build
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Release -destination 'platform=macOS' build
```

### iOS 模拟器构建
```bash
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### 常用构建技巧

**过滤构建结果**:
```bash
# 查看构建是否成功
xcodebuild ... build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED"

# 查看错误信息
xcodebuild ... build 2>&1 | grep -E "error:"

# 查看警告信息
xcodebuild ... build 2>&1 | grep -E "warning:"

# 查看完整的编译错误（包含文件名和行号）
xcodebuild ... build 2>&1 | grep -E "error:"
```

## 代码规范
- **语言**: Swift 6.0, SwiftUI, SwiftData
- **导入顺序**: SwiftUI -> Observation/SwiftData -> Foundation -> App 模块
- **命名规范**: 类型使用 PascalCase，属性和方法使用 camelCase
- **注释规范**: 所有公开 API 和业务逻辑需要添加中文注释
- **错误处理**: 使用 `throws`/`try` 模式，配合 `AppError` 枚举
- **并发处理**: UI 状态默认使用 `@MainActor` 隔离；使用 `Task` 时通过 `await MainActor.run` 更新 UI
- **代码格式**: 4 空格缩进，每行最多 120 字符，SwiftUI 视图需添加 `#Preview`
- **架构模式**: MVVM 架构，使用 Store 模式（`XxxStore` 管理状态，`XxxModel` 管理数据）

## 注意事项
- Flutter 参考实现在 `flutter/` 目录，可用于参考网络请求/UI 布局模式
- 调试网络请求时可在 NetworkClient 中添加日志，并要求用户提供相关的日志。
- 总是使用中文回复用户。

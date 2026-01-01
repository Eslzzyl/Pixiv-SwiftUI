# AGENTS.md

## 构建命令
```bash
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Debug build
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Release build
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
- 存在已知 API 兼容性问题（User.id 类型不一致、部分字段可选），参考现有模型实现
- 调试网络请求时可在 NetworkClient 中添加日志，对照 Flutter 模型排查类型错误
- **macOS 网络权限**: macOS 应用需要配置 entitlements 才能使用系统代理，已在 `Pixiv-SwiftUI/Pixiv-SwiftUI.entitlements` 中添加 `com.apple.security.network.client` 和 `com.apple.security.network.server` 权限

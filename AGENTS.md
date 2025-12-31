# AGENTS.md

## 构建命令
```bash
# Xcode 项目
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Debug build
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Release build

# Python 脚本（需要 uv）
cd python && uv run python test_oauth.py
```

## 代码规范
- **语言**: Swift 5.0, SwiftUI, SwiftData
- **导入顺序**: SwiftUI -> Observation/SwiftData -> Foundation -> App 模块
- **命名规范**: 类型使用 PascalCase，属性和方法使用 camelCase
- **注释规范**: 所有公开 API 和业务逻辑需要添加中文注释
- **错误处理**: 使用 `throws`/`try` 模式，配合 `AppError` 枚举
- **并发处理**: UI 状态默认使用 `@MainActor` 隔离；使用 `Task` 时通过 `await MainActor.run` 更新 UI
- **代码格式**: 4 空格缩进，每行最多 120 字符，SwiftUI 视图需添加 `#Preview`
- **架构模式**: MVVM 架构，使用 Store 模式（`XxxStore` 管理状态，`XxxModel` 管理数据）

## 已知 API 兼容性问题

### User.id 类型不一致
- **问题**: 登录 API (`/auth/token`) 返回 `user.id` 为字符串，推荐 API (`/illust/recommended`) 返回 `user.id` 为整数
- **解决方案**: 创建 `StringIntValue` 枚举类型，实现 `Codable` 协议自动解析 Int 或 String
- **相关文件**: `Pixiv-SwiftUI/Models/User.swift`

### User 部分字段在推荐 API 中可选
- **问题**: 推荐 API 返回的 user 对象缺少 `mail_address`、`is_premium`、`x_restrict`、`is_mail_authorized` 字段
- **解决方案**: 将这些字段声明为可选类型 (`String?`、`Bool?`、`Int?`)
- **相关文件**: `Pixiv-SwiftUI/Models/User.swift`

### 推荐 API 返回未知字段
- **问题**: 推荐 API 返回 `seasonal_effect_animation_urls`、`event_banners`、`request` 等未知字段导致解码失败
- **解决方案**: 从 `Illusts` 模型中移除这些字段，Swift 的 `Codable` 会自动忽略未知字段（只要对应属性不使用 `decodeIfPresent`）
- **相关文件**: `Pixiv-SwiftUI/Models/Illusts.swift`

## 调试技巧

### 添加网络响应调试信息
在 `NetworkClient.swift` 的 `dataTask` 方法中添加调试日志：
```swift
if let body = String(data: data, encoding: .utf8) {
    print("[Network Debug] 响应体预览: \(String(body.prefix(500)))")
}
```

### 类型不匹配错误排查
当出现 "类型不匹配" 错误时：
1. 查看错误信息中的 "实际路径" 确定哪个字段类型不匹配
2. 对照 Flutter 参考模型 (`flutter/models/illust.dart`) 检查预期类型
3. 检查实际 API 响应中的字段类型
4. 必要时将字段改为可选或创建自定义类型（如 `StringIntValue`）

# AGENTS.md

## 构建命令

### macOS 平台构建
```bash
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Debug -destination 'platform=macOS' build
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Release -destination 'platform=macOS' build
```

### iOS 模拟器构建
```bash
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### 常用构建技巧

由于构建输出非常长，必须采用合适的过滤来获取有效输出。

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

## 项目架构

### 目录结构
```
Pixiv-SwiftUI/
├── App/                          # 应用入口
├── Core/                         # 核心基础设施
│   ├── DataModels/              # 数据模型 (Domain/Network/Persistence)
│   ├── Network/                 # 网络层 (Client/API/Endpoints)
│   ├── State/                   # 状态管理 (Stores/Base)
│   └── Storage/                 # 数据存储
├── Features/                     # 功能模块
│   ├── Authentication/          # 认证
│   ├── Home/                    # 主页
│   ├── Search/                  # 搜索
│   ├── Bookmark/                # 收藏
│   ├── User/                    # 用户相关
│   └── General/                 # 通用功能
└── Shared/                       # 共享资源
    ├── Views/                   # 通用视图
    ├── Components/              # UI 组件
    ├── Utils/                   # 工具类
    └── Extensions/              # 扩展
```

### API 层结构
- **AuthAPI**: 认证相关API (登录、令牌刷新)
- **SearchAPI**: 搜索相关API (插画搜索、用户搜索、标签建议)
- **IllustAPI**: 插画相关API (推荐、详情、相关插画)
- **UserAPI**: 用户相关API (用户信息、关注、作品)
- **BookmarkAPI**: 收藏相关API (添加/删除收藏)

### 模型层分离
- **Domain Models**: 领域模型 (User, Illust, Tag 等)
- **Network DTOs**: 网络传输对象 (APIResponses)
- **Persistence Models**: 持久化模型 (SwiftData 实体)

### 依赖注入
项目支持依赖注入模式，通过 `DIContainer` 管理服务：
- NetworkService, AuthService
- CacheService
- Repository 模式支持

## 注意事项
- 项目存在一个 Flutter 参考实现在 `flutter/` 目录，可用于参考网络请求/UI 布局模式
- 关于 API 还存在一个 Python 参考实现 aapi.py。
- 调试网络请求时可在 NetworkClient 中添加日志，并要求用户提供相关的日志。
- 总是使用中文回复用户。

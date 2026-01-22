# AGENTS.md

## 构建命令

开发调试时优先使用 Debug 构建。

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
# 一次性获取构建结果、错误和警告信息
xcodebuild ... build 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"
```

**分段过滤**:
```bash
# 只查看构建结果
xcodebuild ... build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)"

# 只查看错误信息
xcodebuild ... build 2>&1 | grep -E "error:"

# 只查看警告信息
xcodebuild ... build 2>&1 | grep -E "warning:"
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
│   ├── Authentication/           # 认证模块
│   ├── DataModels/              # 数据模型 (Domain/Network/Persistence)
│   │   ├── Domain/              # 领域模型 (User, Illust, Novel, Tag 等)
│   │   ├── Network/             # 网络传输对象
│   │   └── Persistence/         # 持久化模型 (SwiftData 实体)
│   ├── Network/                 # 网络层 (Client/API/Endpoints)
│   │   ├── API/                 # API 实现 (Auth, Bookmark, Illust, Novel, Search, User, Walkthrough)
│   │   ├── Client/              # HTTP 客户端
│   │   └── Endpoints/           # API 端点定义
│   ├── State/                   # 状态管理
│   │   ├── Base/                # 基础组件
│   │   └── Stores/              # 状态存储 (Account, Bookmarks, Download, Illust, Novel, Search, User 等)
│   ├── Storage/                 # 数据存储
│   └── NavigationItem.swift     # 导航项定义
├── Features/                     # 功能模块
│   ├── Authentication/          # 认证 (AuthView)
│   ├── Bookmark/                # 收藏 (BookmarksPage)
│   ├── General/                 # 通用功能
│   │   └── IllustDetail/        # 插画详情 (图片区域、信息区域、相关推荐)
│   ├── Home/                    # 主页
│   │   ├── MainSplitView/       # 主分栏视图
│   │   ├── MainTabView/         # 主标签视图
│   │   ├── RecommendView/       # 推荐页
│   │   └── UpdatesPage/         # 更新页
│   ├── Novel/                   # 小说模块
│   │   ├── Components/          # 小说组件
│   │   ├── NovelDetail/         # 小说详情 (封面、信息区域)
│   │   ├── NovelListPage/       # 小说列表页
│   │   ├── NovelPage/           # 小说页
│   │   ├── NovelRankingPage/    # 小说排行榜
│   │   ├── NovelReaderSettingsView/ # 小说阅读器设置
│   │   ├── NovelReaderView/     # 小说阅读器
│   │   └── NovelSeriesView/     # 小说系列
│   ├── Search/                  # 搜索
│   │   └── Components/          # 搜索组件
│   │   ├── IllustRankingPage/   # 插画排行榜
│   │   ├── SearchResultView/    # 搜索结果
│   │   └── SearchView/          # 搜索页
│   └── User/                    # 用户相关
│       ├── FollowingListView/   # 关注列表
│       ├── NovelWaterfallView/  # 用户小说瀑布流
│       ├── ProfileSettingView/  # 头像设置
│       └── UserDetailView/      # 用户详情
└── Shared/                       # 共享资源
    ├── Components/              # UI 组件 (卡片、评论、列表、下载任务等)
    ├── Extensions/              # 扩展 (Navigation, View)
    ├── Utils/                   # 工具类 (缓存、图片加载、文本解析、下载等)
    └── Views/                   # 通用视图 (设置、历史、下载管理等)
```

### API 层结构
- **AuthAPI**: 认证相关API (登录、令牌刷新)
- **SearchAPI**: 搜索相关API (插画搜索、用户搜索、标签建议)
- **IllustAPI**: 插画相关API (推荐、详情、相关插画)
- **UserAPI**: 用户相关API (用户信息、关注、作品)
- **BookmarkAPI**: 收藏相关API (添加/删除收藏)
- **NovelAPI**: 小说相关API (推荐、详情、系列、排行榜)
- **WalkthroughAPI**: 引导页相关API (首页推荐、趋势标签)

### 模型层分离
- **Domain Models**: 领域模型 (User, Illust, Novel, Tag, Comment, DownloadTask 等)
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
- 调试时可在代码中添加日志，并要求用户提供相关的日志。除非用户要求，你不应该主动删除已经添加的日志。
- 总是使用中文回复用户。

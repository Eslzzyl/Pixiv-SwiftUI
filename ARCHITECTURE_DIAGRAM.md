# Pixiv SwiftUI 应用架构图

## 整体应用架构

```
┌─────────────────────────────────────────────────────────────┐
│                    PixivApp (@main)                         │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ 初始化 DIContainer, DataContainer, Stores              ││
│  │ Features/Authentication, Features/Home, etc.          ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────┐
│                   ContentView                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Core/State/Stores/AccountStore.isLoggedIn              ││
│  │   → Features/ (已登录，显示功能页面)                    ││
│  │ else                                                     ││
│  │   → Features/Authentication/AuthView (登录页面)          ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## 登录流程

```
    AuthView (登录页面)
        ↓
        ┌─────────────────────────────────┐
        │ 用户输入 refresh_token          │
        │ 点击 "登录" 按钮               │
        └──────────────┬──────────────────┘
                       ↓
    AccountStore.loginWithRefreshToken()
        ↓
        ┌──────────────────────────────────┐
        │ PixivAPI.loginWithRefreshToken() │
        │ POST /auth/token                │
        │ {                              │
        │   client_id: "MOBrBDS8..."     │
        │   refresh_token: "user_token"   │
        │   ...                          │
        │ }                              │
        └──────────────┬──────────────────┘
                       ↓
        Pixiv OAuth Server (oauth.secure.pixiv.net)
        {
            access_token: "new_access_token",
            user: { id, name, profile_image_urls, ... }
        }
                       ↓
        ┌──────────────────────────────────┐
        │ AccountStore                     │
        │ 1. 创建 AccountPersist 对象      │
        │ 2. 保存到 SwiftData              │
        │ 3. 设置 isLoggedIn = true        │
        │ 4. 设置 PixivAPI.accessToken     │
        └──────────────┬──────────────────┘
                       ↓
        ContentView 检测到 isLoggedIn 变化
        自动切换到 MainTabView
```

## 推荐页面数据流

```
RecommendView.onAppear()
        ↓
    loadMoreData()
        ↓
    ┌───────────────────────────┐
    │ PixivAPI.shared           │
    │ .getRecommendedIllusts(   │
    │   offset: 0,              │
    │   limit: 30               │
    │ )                         │
    └──────────┬────────────────┘
               ↓
    URLSession.shared.data(from: url)
               ↓
    ┌────────────────────────────────────┐
    │ Pixiv Server: app-api.pixiv.net    │
    │ GET /v1/illust/recommended         │
    │ Headers:                           │
    │   Authorization: Bearer {token}    │
    │   User-Agent: PixivIOSApp/...      │
    └──────────┬─────────────────────────┘
               ↓
    Response: { illusts: [Illust, ...], next_url: "..." }
               ↓
    MainActor.run {
        illusts.append(contentsOf: newIllusts)
        offset += 30
    }
               ↓
    SwiftUI 重新渲染 LazyVGrid
    ┌──────────────────────────┐
    │  LazyVGrid (2 列)        │
    │  ┌────┐  ┌────┐         │
    │  │ C1 │  │ C2 │         │
    │  └────┘  └────┘         │
    │  ┌────┐  ┌────┐         │
    │  │ C3 │  │ C4 │         │
    │  └────┘  └────┘         │
    │  ...更多卡片...         │
    └──────────────────────────┘
               ↓
    用户滚动到末尾
               ↓
    IllustCard.onAppear() 触发 (最后一张卡片)
               ↓
    loadMoreData() 再次调用
               ↓
    加载下一批 30 张插画
```

## 主导航结构

```
Features/Home/MainTabView
    ├─ Tab 0: 推荐
    │   └─ Features/Home/RecommendView
    │       └─ LazyVGrid [Shared/Components/IllustCard, ...]
    │
    ├─ Tab 1: 动态
    │   └─ Features/Home/UpdatesPage
    │       ├── Shared/Components/FollowingHorizontalList (横向关注列表)
    │       └─ LazyVGrid [Shared/Components/IllustCard, ...]
    │
    ├─ Tab 2: 收藏
    │   └─ Features/Bookmark/BookmarksPage
    │       ├── Shared/Components/FloatingCapsulePicker (公开/私有切换)
    │       └─ LazyVGrid [Shared/Components/IllustCard, ...]
    │
    └─ Tab 3: 搜索
        └─ Features/Search/SearchView
            ├── LazyVStack [TrendTag, SearchHistory, ...]
            └─ Shared/Components/ProfileButton (右上角)

所有页面工具栏右侧:
└── Shared/Components/ProfileButton
    └─ Shared/Components/ProfilePanelView (弹出面板)
        ├── 用户信息展示
        ├── 设置按钮
        └── 退出登录按钮
```

## 数据模型关系

```
┌──────────────────┐
│ AccountPersist   │ (SwiftData 持久化)
├──────────────────┤
│ @unique userId   │
│ accessToken      │
│ refreshToken     │
│ userImage        │
│ name             │
│ ...              │
└──────────────────┘
        ↑
        │ (一对一)
        │
┌──────────────────┐
│  AccountStore    │ (@Observable 状态管理)
├──────────────────┤
│ currentAccount   │
│ accounts: []     │
│ isLoggedIn       │
│ isLoading        │
│ error            │
└──────────────────┘
        ↑
        │ (环境变量)
        │
┌──────────────────────────┐
│    ContentView           │
├──────────────────────────┤
│ @Environment(Account)    │
│ @Environment(IllustStore)│
│ @Environment(UserSetting│
│                          │
│ 条件判断 isLoggedIn      │
│ ├─ true  → MainTabView   │
│ └─ false → AuthView      │
└──────────────────────────┘
```

## 组件树

```
PixivApp
└── ContentView
    ├── Features/Home/MainTabView (when isLoggedIn)
    │   ├── Features/Home/RecommendView (Tab 0: 推荐)
    │   │   ├── .toolbar { Shared/Components/ProfileButton() }
    │   │   └── LazyVGrid
    │   │       └── Shared/Components/IllustCard (重复多个)
    │   │           ├── CachedAsyncImage
    │   │           └── VStack (标题、作者、统计)
    │   │
    │   ├── Features/Home/UpdatesPage (Tab 1: 动态)
    │   │   ├── .toolbar { Shared/Components/ProfileButton() }
    │   │   ├── Shared/Components/FollowingHorizontalList
    │   │   │   └── HStack (横向滚动)
    │   │   │       ├── Shared/Components/UserPreviewCard (重复多个)
    │   │   │       │   ├── CachedAsyncImage (头像)
    │   │   │       │   └── Text (用户名)
    │   │   │       └── NavigationLink ("查看全部")
    │   │   └── LazyVGrid
    │   │       └── Shared/Components/IllustCard (重复多个)
    │   │
    │   ├── Features/Bookmark/BookmarksPage (Tab 2: 收藏)
    │   │   ├── .toolbar { Shared/Components/ProfileButton() }
    │   │   ├── Shared/Components/FloatingCapsulePicker
    │   │   │   └── HStack
    │   │   │       ├── Button ("公开")
    │   │   │       └── Button ("私有")
    │   │   └── LazyVGrid
    │   │       └── Shared/Components/IllustCard (重复多个)
    │   │
    │   └── Features/Search/SearchView (Tab 3: 搜索)
    │       ├── .toolbar { TrashButton, Shared/Components/ProfileButton() }
    │       └── LazyVStack
    │           ├── TrendTag (重复多个)
    │           ├── SearchHistory
    │           └── LazyVGrid (搜索结果)
    │
    └── Features/Authentication/AuthView (when !isLoggedIn)
        ├── VStack (title & form)
        │   ├── Image (logo)
        │   ├── Text (title)
        │   ├── SecureField (token input)
        │   ├── Button (login)
        │   └── (error message if exists)

Shared/Components/ProfileButton 点击后:
└── Shared/Components/ProfilePanelView (弹出面板)
    ├── VStack (用户信息)
    │   ├── CachedAsyncImage (头像)
    │   ├── Text (用户名)
    │   └── Text (ID)
    ├── List (设置选项)
    │   ├── NavigationLink ("个人资料设置")
    │   └── Button ("退出登录")
    └── ExportTokenSheet (导出令牌)

Features/User/FollowingListView (独立页面):
└── List
    └── Shared/Components/UserPreviewCard (重复多个)
        ├── CachedAsyncImage (头像)
        ├── VStack (用户信息)
        └── NavigationLink (进入用户详情)

Features/General/IllustDetailView (插画详情页):
└── ScrollView
    ├── CachedAsyncImage (主图片)
    ├── VStack (插画信息)
    │   ├── Text (标题)
    │   ├── HStack (作者信息)
    │   └── Text (描述)
    └── Shared/Components/CommentsPanelView (评论区)
```

## 网络请求流程

```
┌─────────────────────────────────────────┐
│     Core/Network/Client/NetworkClient    │
├─────────────────────────────────────────┤
│                                         │
│  URLSession 配置:                       │
│  ├── User-Agent: PixivIOSApp/6.7.1     │
│  ├── Accept-Language: zh-CN            │
│  ├── Timeout: 30s (request)            │
│  └── Timeout: 300s (resource)          │
│                                         │
│  func get<T: Decodable>()               │
│  ├── 构建 URLRequest                    │
│  ├── 添加自定义请求头                   │
│  ├── 发送请求                          │
│  ├── 检查 HTTP 状态码                   │
│  └── 使用 JSONDecoder 解码响应           │
│                                         │
│  func post<T: Decodable>()              │
│  ├── 类似 get() 但支持请求体             │
│                                         │
└─────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────┐
│       Core/Network/PixivAPI             │
│         (协调器模式)                     │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────────┐ │
│  │  Core/Network/API/AuthAPI          │ │
│  │  ├── loginWithRefreshToken()       │ │
│  │  ├── refreshAccessToken()         │ │
│  │  └── POST /auth/token             │ │
│  └─────────────────────────────────────┘ │
│                                         │
│  ┌─────────────────────────────────────┐ │
│  │  Core/Network/API/SearchAPI        │ │
│  │  ├── getSearchIllust()            │ │
│  │  ├── getSearchAutoComplete()      │ │
│  │  └── GET /v1/search/illust        │ │
│  └─────────────────────────────────────┘ │
│                                         │
│  ┌─────────────────────────────────────┐ │
│  │  Core/Network/API/IllustAPI        │ │
│  │  ├── getRecommendedIllusts()       │ │
│  │  ├── getIllustDetail()            │ │
│  │  └── GET /v1/illust/recommended   │ │
│  └─────────────────────────────────────┘ │
│                                         │
│  ┌─────────────────────────────────────┐ │
│  │  Core/Network/API/UserAPI          │ │
│  │  ├── getUserDetail()              │ │
│  │  ├── followUser()                 │ │
│  │  └── GET /v1/user/detail          │ │
│  └─────────────────────────────────────┘ │
│                                         │
│  ┌─────────────────────────────────────┐ │
│  │  Core/Network/API/BookmarkAPI     │ │
│  │  ├── addBookmark()                │ │
│  │  ├── deleteBookmark()             │ │
│  │  └── POST /v1/illust/bookmark/add│ │
│  └─────────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────┐
│     Pixiv API Server                    │
│  (app-api.pixiv.net)                    │
│  (oauth.secure.pixiv.net)               │
└─────────────────────────────────────────┘
```

## 状态管理流

```
┌─────────────────────────────────┐
│  @Observable Store 类           │
│  (@Observable 宏自动跟踪变化)    │
├─────────────────────────────────┤
│                                 │
│  var currentAccount: Account    │
│  var isLoggedIn: Bool           │
│  var isLoading: Bool            │
│  var error: Error?              │
│                                 │
│  func loginWithRefreshToken()   │
│  func logout()                  │
│  func switchAccount()           │
│                                 │
└──────────┬──────────────────────┘
           │ (属性变化自动通知)
           ↓
┌─────────────────────────────────┐
│  @Environment 注入到视图          │
├─────────────────────────────────┤
│                                 │
│  @Environment(AccountStore)     │
│  var accountStore               │
│                                 │
│  // 视图自动响应变化              │
│  if accountStore.isLoggedIn {   │
│      // 显示主视图               │
│  } else {                       │
│      // 显示登录视图              │
│  }                              │
│                                 │
└─────────────────────────────────┘
```

## 数据持久化流程

```
SwiftData ModelContainer
        ↓
┌──────────────────────────────┐
│   DataContainer.shared       │
│  - modelContainer            │
│  - mainContext               │
│  - backgroundContext         │
└──────────┬───────────────────┘
           ↓
┌──────────────────────────────┐
│   FetchDescriptor<Model>     │
│                              │
│  用于查询 SwiftData 中的对象  │
│  支持谓词过滤和排序          │
└──────────┬───────────────────┘
           ↓
┌──────────────────────────────┐
│   @Model 标注的类             │
│                              │
│  @Model                      │
│  final class Account {       │
│    @Attribute(.unique)       │
│    var id: String            │
│    var name: String          │
│  }                           │
└──────────┬───────────────────┘
           ↓
┌──────────────────────────────┐
│   SQLite Database            │
│  (本地文件系统)              │
│                              │
│  /.../containers/           │
│      shared.data             │
│      shared.wal              │
│      shared.shm              │
└──────────────────────────────┘
```

## 错误处理流程

```
User Action
    ↓
try/catch 块
    ├─ success: 更新状态
    └─ error:
        ↓
        ┌──────────────────────┐
        │  错误分类             │
        ├──────────────────────┤
        │                      │
        ├─ NetworkError        │
        │  └─ connectionError  │
        │                      │
        ├─ DatabaseError      │
        │  └─ saveFailed      │
        │                      │
        ├─ DecodingError      │
        │  └─ invalidFormat   │
        │                      │
        └─ AuthError          │
           └─ invalidToken    │
        │                      │
        └──────────────────────┘
            ↓
        store.error = error
            ↓
        View 检测到 error 不为 nil
            ↓
        显示 HStack {
            Image("exclamationmark")
            Text(error.localizedDescription)
        }
            ↓
        用户可以点击"重试"按钮
```

## 总结

该应用采用**模块化分层架构**：

1. **Core 层**: 核心基础设施，提供跨功能共享服务
   - DataModels: 数据模型 (Domain/Network/Persistence)
   - Network: 网络通信模块化设计
   - State: 状态管理和依赖注入
   - Storage: 数据存储服务

2. **Features 层**: 业务功能模块，垂直切分
   - Authentication: 认证功能
   - Home: 主页功能
   - Search: 搜索功能
   - Bookmark: 收藏功能
   - User: 用户相关功能
   - General: 通用功能

3. **Shared 层**: 可复用资源和组件
   - Views: 通用视图
   - Components: UI组件库
   - Utils: 工具类和扩展
   - Extensions: 系统扩展

## 架构优势

- **模块化**: 功能独立，便于开发和维护
- **可扩展**: 新功能可独立开发，不影响现有模块
- **可测试**: 分层设计便于单元测试和集成测试
- **可复用**: Shared层组件可在多个功能中复用

**数据流向**：
用户操作 → Features/View → Core/State/Store → Core/Network/API → API 响应 → Core/State/Store → Features/View 自动重新渲染

这种模块化架构清晰、易于测试、支持独立开发和部署。

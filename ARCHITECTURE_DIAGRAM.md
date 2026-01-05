# Pixiv SwiftUI 应用架构图

## 整体应用架构

```
┌─────────────────────────────────────────────────────────────┐
│                    PixivApp (@main)                         │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ 初始化 DataContainer, AccountStore, IllustStore         ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   ContentView                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ if accountStore.isLoggedIn                              ││
│  │   → MainTabView (已登录，显示主页面)                     ││
│  │ else                                                     ││
│  │   → AuthView (未登录，显示登录页面)                      ││
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
MainTabView
    ├─ Tab 0: 推荐
    │   └─ RecommendView
    │       └─ LazyVGrid [IllustCard, ...]
    │
    ├─ Tab 1: 动态
    │   └─ UpdatesPage
    │       ├── FollowingHorizontalList (横向关注列表)
    │       └─ WaterfallGrid [IllustCard, ...]
    │
    ├─ Tab 2: 收藏
    │   └─ BookmarksPage
    │       ├── FloatingCapsulePicker (公开/私有切换)
    │       └─ WaterfallGrid [IllustCard, ...]
    │
    └─ Tab 3: 搜索
        └─ SearchView
            ├── LazyVStack [TrendTag, SearchHistory, ...]
            └─ ProfileButton (右上角)

所有页面工具栏右侧:
└── ProfileButton
    └─ ProfilePanelView (弹出面板)
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
    ├── MainTabView (when isLoggedIn)
    │   ├── RecommendView (Tab 0: 推荐)
    │   │   ├── .toolbar { ProfileButton() }
    │   │   └── LazyVGrid
    │   │       └── IllustCard (重复多个)
    │   │           ├── CachedAsyncImage
    │   │           └── VStack (标题、作者、统计)
    │   │
    │   ├── UpdatesPage (Tab 1: 动态)
    │   │   ├── .toolbar { ProfileButton() }
    │   │   ├── FollowingHorizontalList
    │   │   │   └── HStack (横向滚动)
    │   │   │       ├── UserPreviewCard (重复多个)
    │   │   │       │   ├── CachedAsyncImage (头像)
    │   │   │       │   └── Text (用户名)
    │   │   │       └── NavigationLink ("查看全部")
    │   │   └── WaterfallGrid
    │   │       └── IllustCard (重复多个)
    │   │
    │   ├── BookmarksPage (Tab 2: 收藏)
    │   │   ├── .toolbar { ProfileButton() }
    │   │   ├── FloatingCapsulePicker
    │   │   │   └── HStack
    │   │   │       ├── Button ("公开")
    │   │   │       └── Button ("私有")
    │   │   └── WaterfallGrid
    │   │       └── IllustCard (重复多个)
    │   │
    │   └── SearchView (Tab 3: 搜索)
    │       ├── .toolbar { TrashButton, ProfileButton() }
    │       └── LazyVStack
    │           ├── TrendTag (重复多个)
    │           ├── SearchHistory
    │           └── WaterfallGrid (搜索结果)
    │
    └── AuthView (when !isLoggedIn)
        ├── VStack (title & form)
        │   ├── Image (logo)
        │   ├── Text (title)
        │   ├── SecureField (token input)
        │   ├── Button (login)
        │   └── (error message if exists)

ProfileButton 点击后:
└── ProfilePanelView (弹出面板)
    ├── VStack (用户信息)
    │   ├── CachedAsyncImage (头像)
    │   ├── Text (用户名)
    │   └── Text (ID)
    ├── List (设置选项)
    │   ├── NavigationLink ("个人资料设置")
    │   └── Button ("退出登录")
    └── ExportTokenSheet (导出令牌)

FollowingListView (独立页面):
└── List
    └── UserPreviewCard (重复多个)
        ├── CachedAsyncImage (头像)
        ├── VStack (用户信息)
        └── NavigationLink (进入用户详情)
```

## 网络请求流程

```
┌─────────────────────────────────────────┐
│          NetworkClient.swift            │
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
│           PixivAPI.swift                │
├─────────────────────────────────────────┤
│                                         │
│  accessToken: 存储当前 token            │
│                                         │
│  authHeaders: {                         │
│    Authorization: "Bearer {token}"      │
│    Accept: "application/json"           │
│    Content-Type: "application/json"     │
│  }                                      │
│                                         │
│  loginWithRefreshToken()                │
│  ├── POST /auth/token                  │
│  ├── 请求体包含 client_id, secret      │
│  └── 返回 (accessToken, user)           │
│                                         │
│  getRecommendedIllusts()                │
│  ├── GET /v1/illust/recommended        │
│  ├── 参数: offset, limit               │
│  └── 返回 [Illusts]                     │
│                                         │
│  ... (其他 API 方法)                     │
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

该应用采用**分层架构**：

1. **UI 层** (Views): SwiftUI 视图，负责展示
2. **状态管理层** (Store): @Observable 类，管理应用状态
3. **网络层** (Network): URLSession 封装，处理 API 请求
4. **数据层** (Models): SwiftData 模型，本地持久化

**数据流向**：
用户操作 → View 事件 → Store 方法 → Network 请求 → API 响应 → Store 状态更新 → View 自动重新渲染

这种架构清晰、易于测试和扩展。

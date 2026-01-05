# SwiftUI Pixiv 客户端 - 项目架构

## 项目概述

这是一个基于 SwiftUI 和 SwiftData 的 Pixiv 客户端，支持 iOS、iPadOS 和 macOS。项目采用分层架构。

## 目录结构

```
Pixiv-SwiftUI/
├── App/                          # 应用入口
│   └── PixivApp.swift         # 主应用入口和场景配置
│
├── Core/                         # 核心基础设施
│   ├── DataModels/              # 数据模型
│   │   ├── Domain/             # 领域模型
│   │   │   ├── User.swift      # 用户相关模型
│   │   │   ├── Illust.swift    # 插画主模型
│   │   │   ├── Tag.swift       # 标签模型
│   │   │   ├── ImageUrls.swift # 图片URL模型
│   │   │   ├── MetaPages.swift # 多页面元数据
│   │   │   └── ...           # 其他领域模型
│   │   ├── Network/            # 网络传输对象
│   │   │   └── APIResponses.swift # API响应结构
│   │   └── Persistence/        # 持久化模型
│   │       └── Persistence.swift # SwiftData实体
│   │
│   ├── Network/                 # 网络层
│   │   ├── Client/             # 基础客户端
│   │   │   └── NetworkClient.swift # HTTP客户端基类
│   │   ├── API/                # 业务API
│   │   │   ├── AuthAPI.swift   # 认证API
│   │   │   ├── SearchAPI.swift # 搜索API
│   │   │   ├── IllustAPI.swift # 插画API
│   │   │   ├── UserAPI.swift   # 用户API
│   │   │   └── BookmarkAPI.swift # 收藏API
│   │   ├── Endpoints/          # API端点
│   │   │   └── PixivEndpoint.swift # API端点定义
│   │   └── PixivAPI.swift      # API协调器类
│   │
│   ├── State/                   # 状态管理
│   │   ├── Base/               # 基础类和协议
│   │   │   ├── Protocols.swift # 服务协议
│   │   │   └── DIContainer.swift # 依赖注入容器
│   │   └── Stores/             # 功能状态管理
│   │       ├── DataContainer.swift # SwiftData容器
│   │       ├── AccountStore.swift # 账户状态
│   │       ├── IllustStore.swift  # 插画状态
│   │       ├── UpdatesStore.swift # 动态页面状态
│   │       ├── BookmarksStore.swift # 收藏状态
│   │       ├── FollowingListStore.swift # 关注列表状态
│   │       └── UserSettingStore.swift # 用户设置状态
│   │
│   └── Storage/                 # 数据存储
│       └── [存储相关配置文件]
│
├── Features/                     # 功能模块
│   ├── Authentication/          # 认证功能
│   │   └── AuthView.swift      # 登录页面
│   ├── Home/                   # 主页功能
│   │   ├── MainTabView.swift   # 主标签页
│   │   ├── RecommendView.swift # 推荐页面
│   │   └── UpdatesPage.swift   # 动态页面
│   ├── Search/                 # 搜索功能
│   │   └── SearchView.swift    # 搜索页面
│   ├── Bookmark/               # 收藏功能
│   │   └── BookmarksPage.swift # 收藏页面
│   ├── User/                   # 用户相关
│   │   ├── UserDetailView.swift # 用户详情页
│   │   ├── FollowingListView.swift # 关注列表
│   │   └── ProfileSettingView.swift # 个人设置
│   └── General/                # 通用功能
│       ├── IllustDetailView.swift # 插画详情页
│       └── LaunchScreenView.swift # 启动页
│
└── Shared/                       # 共享资源
    ├── Views/                   # 通用视图
    │   ├── BlockSettingView.swift # 屏蔽设置
    │   ├── BrowseHistoryView.swift # 浏览历史
    │   ├── DownloadSettingView.swift # 下载设置
    │   ├── DownloadTasksView.swift # 下载任务
    │   ├── IconDesignView.swift # 图标设计
    │   └── TranslationSettingView.swift # 翻译设置
    │
    ├── Components/              # UI组件
    │   ├── ProfileButton.swift      # 个人资料按钮
    │   ├── ProfilePanelView.swift   # 个人资料面板
    │   ├── FloatingCapsulePicker.swift # 浮动选择器
    │   ├── FollowingHorizontalList.swift # 横向关注列表
    │   ├── WaterfallGrid.swift      # 瀑布流网格
    │   ├── IllustCard.swift         # 插画卡片
    │   ├── CommentsPanelView.swift  # 评论面板
    │   └── ... (其他组件)
    │
    ├── Utils/                   # 工具类
    │   ├── Helpers.swift         # 辅助函数
    │   ├── CacheManager.swift    # 缓存管理
    │   ├── ImageSaver.swift     # 图片保存
    │   ├── PKCEHelper.swift      # PKCE认证辅助
    │   └── ... (其他工具)
    │
    └── Extensions/              # 扩展
        └── [扩展文件]
```

## 核心架构

### 1. 数据层 (Models)

所有数据模型都使用 `@Model` 宏标注，以支持 SwiftData 持久化：

**用户相关** (`User.swift`):
- `ProfileImageUrls`: 用户头像 URL 集合
- `User`: 用户基本信息
- `AccountResponse`: 登录响应
- `AccountPersist`: 持久化的账户信息

**插画相关** (`Illusts.swift`):
- `Tag`: 标签信息
- `ImageUrls`: 图片 URL 集合
- `MetaSinglePage` / `MetaPages*`: 页面元数据
- `IllustSeries`: 系列信息
- `Illusts`: 完整的插画数据

**设置相关** (`UserSetting.swift`):
- `UserSetting`: 用户界面和功能配置

**持久化数据** (`Persistence.swift`):
- `BanIllustId`, `BanUserId`, `BanTag`: 禁用列表
- `GlanceIllustPersist`: 浏览历史
- `TaskPersist`: 下载任务

### 2. 状态管理层 (Store)

使用 SwiftUI 的 `@Observable` 宏（iOS 17+）进行状态管理：

**DataContainer.swift**:
- 集中管理 SwiftData 的 `ModelContainer`
- 提供全局数据上下文
- 负责数据库初始化和配置

**AccountStore.swift**:
- 管理用户认证状态
- 处理账户切换和多账户管理
- 提供账户增删改查操作

**IllustStore.swift**:
- 管理插画数据缓存
- 处理收藏、禁用、历史记录等逻辑
- 提供灵活的查询接口

**UpdatesStore.swift**:
- 管理关注用户的动态更新数据
- 处理关注列表和动态插画的加载
- 支持分页加载和刷新

**BookmarksStore.swift**:
- 管理用户收藏的插画数据
- 支持公开/私有收藏切换
- 处理收藏内容的分页加载

**FollowingListStore.swift**:
- 管理关注用户列表数据
- 支持分页加载关注用户
- 提供关注用户预览信息

**UserSettingStore.swift**:
- 管理用户偏好设置
- 提供类型安全的设置访问方法
- 自动持久化设置更改

### 3. 网络层 (Network)

**NetworkClient.swift**:
- 基于 URLSession 的 HTTP 客户端
- 处理请求头设置和响应解析
- 统一的错误处理
- 支持直连和常规模式切换

**API模块化设计**:
- **AuthAPI**: 认证相关（登录、令牌刷新）
- **SearchAPI**: 搜索功能（插画搜索、用户搜索、标签建议）
- **IllustAPI**: 插画功能（推荐、详情、相关插画、评论）
- **UserAPI**: 用户功能（用户信息、关注管理、作品列表）
- **BookmarkAPI**: 收藏功能（添加/删除收藏）

**PixivAPI.swift**:
- 协调器模式，整合各个专门API
- 提供统一的接口层
- 管理认证状态和请求头
- 保持向后兼容性

### 4. UI 层 (Views)

使用 SwiftUI 构建响应式 UI，支持多平台：

**主要页面**:
- **推荐页面** (`RecommendView`): 展示推荐插画瀑布流
- **动态页面** (`UpdatesPage`): 展示关注用户的动态更新
- **收藏页面** (`BookmarksPage`): 展示用户收藏内容，支持公开/私有切换
- **搜索页面** (`SearchView`): 提供插画搜索功能

**个人资料相关**:
- **ProfileButton**: 工具栏中的圆形头像按钮
- **ProfilePanelView**: 弹出式个人资料面板（iOS 使用 sheet，macOS 使用 popover）

**列表和详情**:
- **FollowingListView**: 完整的关注用户列表页面
- **IllustDetailView**: 插画详情页面

**通用组件**:
- **WaterfallGrid**: 瀑布流网格布局
- **FloatingCapsulePicker**: 浮动胶囊样式选择器
- **FollowingHorizontalList**: 横向滚动的关注用户预览列表

### 5. 工具层 (Utils)

**Helpers.swift**:
- 图片 URL 处理
- 日期格式化
- 文本清理和 HTML 实体解码
- 数值格式化
- 输入验证

## 关键设计决策

### 架构分层原则

- **Core**: 核心基础设施，跨功能共享
- **Features**: 业务功能模块，按功能垂直切分
- **Shared**: 通用资源和组件，可复用

### API 模块化设计

- **单一职责**: 每个API类专注一个业务领域
- **协调器模式**: PixivAPI作为统一入口
- **依赖注入**: 通过DIContainer管理服务

### SwiftData vs UserDefaults

- **简单设置**: UserDefaults
- **复杂对象和关系**: SwiftData
- **本项目**: 全部使用 SwiftData 以便统一管理和迁移

### @Observable 状态管理

相比 `@StateObject` + `ObservableObject`：
- 更简洁的语法
- 自动跟踪属性变化
- 更好的性能
- 需要 iOS 17+

### 网络请求处理

- 使用 `async/await` 替代闭包回调
- 统一的错误处理和重试逻辑
- 支持取消请求（通过 `Task` 取消）

### 依赖注入模式

- **DIContainer**: 集中管理服务依赖
- **协议抽象**: 定义服务接口，支持测试和替换
- **Repository模式**: 分离数据访问逻辑

## 数据流示例

```
UI (View) 
  ↓
State (@Observable Store)
  ↓
Business Logic (Store methods)
  ↓
Data Layer (SwiftData)
  ↓
Network (PixivAPI)
  ↓
Remote Server
```

## 技术栈

- **UI Framework**: SwiftUI
- **Data Persistence**: SwiftData
- **State Management**: @Observable
- **Networking**: URLSession, async/await

## 代码风格

- 使用 Swift 5.9+ 语法
- 中文注释说明业务逻辑
- 类型安全优先
- 错误处理完善
- MARK 分组组织代码

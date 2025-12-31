# SwiftUI Pixiv 客户端 - 项目架构

## 项目概述

这是一个基于 SwiftUI 和 SwiftData 的 Pixiv 客户端，支持 iOS、iPadOS 和 macOS。项目采用分层架构，从 Flutter 版本渐进式迁移而来。

## 目录结构

```
Pixiv-SwiftUI/
├── App/                      # 应用入口
│   └── PixivApp.swift       # 主应用入口和场景配置
│
├── Models/                   # 数据模型
│   ├── User.swift           # 用户和账户相关模型
│   ├── Illusts.swift        # 插画和相关数据模型
│   ├── UserSetting.swift    # 用户设置模型
│   └── Persistence.swift    # 持久化数据模型（禁用、历史等）
│
├── Store/                    # 状态管理（使用 @Observable）
│   ├── DataContainer.swift  # SwiftData 容器配置
│   ├── AccountStore.swift   # 账户管理
│   ├── IllustStore.swift    # 插画管理
│   └── UserSettingStore.swift # 用户设置管理
│
├── Network/                  # 网络通信
│   ├── NetworkClient.swift  # HTTP 客户端基类
│   └── PixivAPI.swift       # Pixiv API 包装
│
├── Views/                    # UI 视图层（待实现）
│   ├── Home/                # 主页相关视图
│   ├── Search/              # 搜索相关视图
│   ├── Auth/                # 认证相关视图
│   └── Components/          # 通用组件
│
└── Utils/                    # 工具函数
    └── Helpers.swift        # 各类辅助函数
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

**UserSettingStore.swift**:
- 管理用户偏好设置
- 提供类型安全的设置访问方法
- 自动持久化设置更改

### 3. 网络层 (Network)

**NetworkClient.swift**:
- 基于 URLSession 的 HTTP 客户端
- 处理请求头设置和响应解析
- 统一的错误处理

**PixivAPI.swift**:
- 对 Pixiv 官方 API 的包装
- 提供易用的接口（推荐、搜索、详情等）
- 自动处理认证令牌

### 4. UI 层 (Views)

使用 SwiftUI 构建响应式 UI，支持多平台：
- 主页（推荐、排行等）
- 搜索页面
- 个人主页
- 详情页面

### 5. 工具层 (Utils)

**Helpers.swift**:
- 图片 URL 处理
- 日期格式化
- 文本清理和 HTML 实体解码
- 数值格式化
- 输入验证

## 关键设计决策

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

## 迁移进度

按照 `plan.md` 的步骤：

1. ✅ **建立 SwiftUI 骨架与平台基础** - 完成
   - 项目结构建立
   - SwiftData 容器配置
   - 基本的应用入口

2. ✅ **迁移数据模型** - 完成
   - 用户和账户模型
   - 插画相关模型
   - 设置和持久化模型

3. ⏳ **实现最小网络层** - 进行中
   - 基础网络客户端完成
   - API 包装完成
   - 需要添加认证流程

4. ⏳ **实现 MobX 替代品** - 进行中
   - AccountStore 完成
   - IllustStore 完成
   - UserSettingStore 完成
   - 需要集成到 UI

5. 🔲 **迁移登录与账号管理** - 待开始
6. 🔲 **构建推荐页 UI** - 待开始
7. 🔲 **添加插画详情页** - 待开始
8. 🔲 **逐步扩展功能** - 待开始

## 下一步任务

1. **实现登录流程**
   - OAuth 认证集成
   - 令牌存储和刷新
   - 多账户切换 UI

2. **构建推荐页**
   - LazyVGrid 布局
   - 图片加载和缓存
   - R-18 过滤

3. **详情页实现**
   - 评论加载
   - 收藏/取消收藏
   - 下载功能

4. **网络绕过方案**
   - DNS 解析替代
   - SNI 绕过
   - 代理配置

## 技术栈

- **UI Framework**: SwiftUI
- **Data Persistence**: SwiftData
- **State Management**: @Observable
- **Networking**: URLSession, async/await
- **Target Platform**: iOS 17+, iPadOS 17+, macOS 14+

## 代码风格

- 使用 Swift 5.9+ 语法
- 中文注释说明业务逻辑
- 类型安全优先
- 错误处理完善
- MARK 分组组织代码

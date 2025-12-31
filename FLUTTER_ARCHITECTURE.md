# Flutter Pixiv 客户端 - 项目架构分析

## 项目概述

这是一个基于 Flutter 的跨平台 Pixiv 客户端，支持 iOS、Android、Windows、macOS 等多个平台。项目采用分层架构设计，清晰的模块划分和依赖关系使得代码易于维护和扩展。

## 整体架构图

```
┌─────────────────────────────────────────────────────┐
│                    UI 层 (Pages & Components)         │
│  ┌──────────────────────────────────────────────┐   │
│  │ page/ - 页面                                   │   │
│  │ component/ - UI 组件                          │   │
│  │ fluent/ - Windows Fluent UI 主题              │   │
│  └──────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────┤
│           状态管理与业务逻辑层 (Store & ER)          │
│  ┌──────────────────────────────────────────────┐   │
│  │ store/ - MobX Store（状态管理）               │   │
│  │ er/ - 工具与辅助类                           │   │
│  │   ├── Fetcher - 下载管理                      │   │
│  │   ├── ApiClient 相关                          │   │
│  │   └── 其他工具                               │   │
│  └──────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────┤
│              网络与数据层 (Network & Models)          │
│  ┌──────────────────────────────────────────────┐   │
│  │ network/ - API 客户端                        │   │
│  │ models/ - 数据模型                           │   │
│  └──────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────┤
│          应用基础设施 (Core Infrastructure)           │
│  ┌──────────────────────────────────────────────┐   │
│  │ main.dart - 应用入口                          │   │
│  │ constants.dart - 常量定义                     │   │
│  │ i18n.dart - 国际化支持                        │   │
│  │ exts.dart - 扩展方法                          │   │
│  │ Platform Plugins - 平台集成插件              │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## 核心模块详解

### 1. UI 层 (UI Layer)

#### 1.1 pages/ - 页面模块

```
page/
├── Init/                    # 应用初始化相关页面
├── about/                   # 关于页面
├── account/                 # 账户管理页面
├── board/                   # 看板/讨论版页面
├── book/                    # 书籍/文库页面
├── comment/                 # 评论页面
├── create/                  # 创建内容相关页面
├── directory/               # 目录/浏览页面
├── follow/                  # 关注相关页面
├── hello/                   # 欢迎/问候页面
├── history/                 # 历史记录页面
├── login/                   # 登录/认证页面
├── network/                 # 网络相关页面
├── novel/                   # 小说相关页面
├── painter/                 # 画师/创作者页面
├── picture/                 # 插画详情页面
├── platform/                # 平台特定功能页面
├── preview/                 # 预览页面
├── report/                  # 举报页面
├── saucenao/                # 反向搜索页面
├── search/                  # 搜索页面
├── series/                  # 系列作品页面
├── shield/                  # 屏蔽/禁用页面
├── soup/                    # 周边商品页面
├── splash/                  # 启动页面
├── spotlight/               # 聚焦/特推页面
├── task/                    # 任务管理页面
├── theme/                   # 主题设置页面
├── user/                    # 用户信息页面
├── vision/                  # AI 视觉相关页面
├── watchlist/               # 观看列表页面
└── webview/                 # 网页视图页面
```

**特点**:
- 每个页面通常包含对应的 `PageWidget` 和 `PageStore`（MobX Store）
- 页面通过导航栈进行管理
- 支持平台特定的导航（如 Windows 的 Fluent 导航）

#### 1.2 component/ - UI 组件库

```
component/
├── anim_expand.dart               # 展开/收起动画组件
├── ban_page.dart                  # 禁用提示页面
├── comment_emoji_text.dart        # 评论表情文本渲染
├── common_back_area.dart          # 通用返回区域
├── empty_page.dart                # 空状态页面
├── fail_face.dart                 # 失败表情提示
├── follow_detail_alert.dart       # 关注详情对话框
├── illust_card.dart               # 插画卡片（重要组件）
├── new_version_chip.dart          # 新版本提示芯片
├── null_hero.dart                 # Hero 动画兼容层
├── painer_card.dart               # 画师卡片
├── painter_avatar.dart            # 画师头像
├── pixez_default_header.dart      # 默认头部组件
├── pixiv_image_shielded.dart      # 带屏蔽的图片显示
├── pixiv_image.dart               # 核心图片加载组件
├── selectable_html.dart           # 可选择的 HTML 渲染
├── sort_group.dart                # 排序分组组件
├── spotlight_card.dart            # 特推卡片
├── staggered_illust.dart          # 瀑布流插画布局
├── star_icon.dart                 # 星标/收藏图标
├── ugoira_painter.dart            # 动图播放器
└── picker/                        # 选择器组件库
```

**核心组件说明**:

- **pixiv_image.dart**: 图片加载的核心组件，集成了缓存管理和代理处理
- **illust_card.dart**: 插画卡片，展示插画缩略图、作者信息、R-18 过滤等
- **staggered_illust.dart**: 瀑布流布局，用于网格展示

#### 1.3 fluent/ - Windows Fluent UI 主题

```
fluent/
├── fluentui.dart                # Fluent UI 主题和窗口配置
├── navigation_framework.dart    # Fluent 导航框架
├── component/                   # Fluent 特定组件
├── lighting/                    # Fluent 亮度/外观设置
└── page/                        # Fluent 特定页面
```

**说明**:
- 仅在 Windows 平台启用（由 `Constants.isFluent` 控制）
- 提供原生 Windows 11 界面风格
- 使用 `fluent_ui` 包实现

### 2. 状态管理与业务逻辑层

#### 2.1 store/ - MobX 状态管理

```
store/
├── user_setting.dart          # 用户设置（核心店铺）
├── account_store.dart         # 账户管理
├── tag_history_store.dart     # 标签历史
├── book_tag_store.dart        # 文库标签
├── save_store.dart            # 下载保存相关
├── mute_store.dart            # 禁用/屏蔽管理
├── fullscreen_store.dart      # 全屏状态
└── top_store.dart             # 顶部导航状态
```

**MobX 模式说明**:
- 使用 `@observable` 标注可观察的状态
- 使用 `@action` 标注状态修改方法
- 使用 `@computed` 定义派生状态
- 生成对应的 `.g.dart` 文件用于代码生成

**user_setting.dart 详解** (最重要的 Store):
- 管理全局用户偏好设置
- 包含 UI 设置（语言、主题等）、功能设置、隐私设置等
- 自动持久化到本地存储（SharedPreferences）
- 支持热重载设置

#### 2.2 er/ - 工具与服务层

```
er/
├── fetcher.dart               # 下载管理器（核心）
│   └── 使用 Isolate 实现后台下载
│   └── 支持任务队列和进度追踪
│   └── 结合平台特定的存储 API
│
├── hoster.dart                # 主机/DNS 解析
│   └── 实现 DNS 查询和解析
│   └── 支持 SNI 绕过
│   └── 管理 IP 映射表
│
├── api_client.dart            # API 请求的核心逻辑（另见 network/）
├── oauth_client.dart          # OAuth 认证客户端
├── leader.dart                # 路由导航管理器
├── fluent_leader.dart         # Fluent 特定的导航
├── prefer.dart                # 本地偏好存储包装
├── sharer.dart                # 分享功能
├── toaster.dart               # 消息提示 (Toast/Snackbar)
├── lprinter.dart              # 日志打印工具
└── updater.dart               # 应用更新检查
```

**关键组件**:

- **fetcher.dart**: 下载管理的核心
  - 使用 `Isolate` 实现后台任务不阻塞主线程
  - `IsoContactBean`: Isolate 间通信协议
  - 支持任务持久化和恢复
  - 集成平台特定的文件存储 API

- **hoster.dart**: 网络代理/DNS 管理
  - 管理主机映射表
  - 支持 DNS over HTTPS (DoH) 查询
  - 实现 SNI 绕过机制
  - 使用 Rhttp 库处理底层网络

### 3. 网络与数据层

#### 3.1 network/ - API 客户端

```
network/
├── api_client.dart            # Pixiv API 完整包装
│   ├── 认证与授权
│   ├── 推荐/搜索/排行 API
│   ├── 用户/插画/小说 API
│   ├── 收藏/关注 API
│   └── 评论/报告 API
│
├── oauth_client.dart          # OAuth 2.0 认证
│   └── 处理 token 获取和刷新
│
├── account_client.dart        # 账户管理 API
│
├── onezero_client.dart        # 额外的 API 端点
│
└── refresh_token_interceptor.dart  # 请求拦截器
    └── 自动刷新过期 token
```

**api_client.dart 特点**:
- 基于 Dio HTTP 库
- 集成缓存拦截器
- 支持自定义请求头（User-Agent、语言等）
- 实现 MD5 签名认证
- 支持多种响应格式解析

#### 3.2 models/ - 数据模型

```
models/
├── 账户相关
│   ├── account.dart
│   ├── account_edit_response.dart
│   ├── user_detail.dart
│   ├── user_preview.dart
│   └── create_user_response.dart
│
├── 插画相关（核心）
│   ├── illust.dart                    # 插画主模型
│   ├── illust_persist.dart            # 插画持久化数据
│   ├── illust_bookmark_tags_response.dart
│   ├── illust_series_detail.dart
│   ├── illust_series_with_id_model.dart
│   └── amwork.dart                    # 动画作品模型
│
├── 小说相关
│   ├── novel_persist.dart
│   ├── novel_series_detail.dart
│   ├── novel_text_response.dart
│   ├── novel_viewer_persist.dart
│   ├── novel_recom_response.dart
│   ├── novel_web_response.dart
│   └── novel_watch_list_model.dart
│
├── 用户屏蔽/禁用
│   ├── ban_comment_persist.dart       # 屏蔽评论
│   ├── ban_illust_id.dart             # 禁用插画
│   ├── ban_tag.dart                   # 禁用标签
│   └── ban_user_id.dart               # 禁用用户
│
├── 其他
│   ├── tags.dart                      # 标签模型
│   ├── follow_detail.dart             # 关注详情
│   ├── bookmark.dart                  # 收藏
│   ├── bookmark_detail.dart
│   ├── comment_response.dart          # 评论
│   ├── task_persist.dart              # 任务持久化
│   ├── glance_illust_persist.dart     # 浏览历史
│   ├── trend_tags.dart                # 热门标签
│   ├── spotlight_response.dart        # 聚焦内容
│   ├── show_ai_response.dart          # AI 相关
│   ├── error_message.dart             # 错误消息
│   ├── ranking.dart                   # 排行
│   ├── recommend.dart                 # 推荐
│   ├── ugoira_metadata_response.dart  # 动图元数据
│   ├── onezero_response.dart          # OneZero API 响应
│   ├── board_info.dart                # 看板信息
│   ├── watchlist_manga_model.dart     # 漫画观看列表
│   ├── key_value_pair.dart            # 键值对
│   └── export_tag_history_data.dart   # 标签历史导出
```

**模型设计特点**:
- 使用 `json_serializable` 进行 JSON 序列化/反序列化
- 支持复杂的嵌套对象结构
- 为敏感数据提供持久化支持（如 `*_persist.dart`）

### 4. 应用基础设施

#### 4.1 main.dart - 应用入口

```dart
// 关键初始化序列：
1. Rhttp 库初始化 (处理网络请求)
2. WidgetsFlutterBinding.ensureInitialized()
3. 平台特定初始化:
   - Windows/Linux: sqflite 数据库配置
   - 所有平台: SingleInstancePlugin (防止多个实例)
4. Fluent UI 初始化 (仅 Windows)
5. 创建全局 Store 实例:
   - UserSetting (用户设置)
   - SaveStore (下载管理)
   - MuteStore (屏蔽管理)
   - AccountStore (账户管理)
   - TagHistoryStore (标签历史)
   - NovelHistoryStore (小说历史)
   - TopStore (顶部导航)
   - BookTagStore (文库标签)
   - SplashStore (启动页)
   - Fetcher (下载器)
   - FullScreenStore (全屏状态)
6. 启动 ProviderScope (Riverpod 状态管理)
7── 运行应用
```

**全局 Store 说明**:
- 这些都是单例实例，在应用启动时创建
- 通过 `main.dart` 导出供全应用使用
- `UserSetting` 是最重要的全局设置 Store

#### 4.2 constants.dart - 常量定义

```dart
Constants {
  no_h: 'assets/images/h_long.jpg'      // R-18 替代图片
  tagName: '0.9.80'                     // 版本号
  isGooglePlay: bool                    // Google Play 环境标志
  type: int                             // 应用类型
  code_verifier: String?                // OAuth 验证码
  isFluent: bool                        // 是否使用 Fluent UI (Windows)
}
```

#### 4.3 i18n.dart - 国际化支持

```dart
支持的语言:
- 中文 (简体、繁体)
- 英文 (美国、通用)
- 日语
- 韩语
- 德语
- 西班牙语
- 俄语
- 土耳其语
- 印尼语 (两个版本)
- 菲律宾语

对应的 .arb 文件在 l10n/ 目录
```

#### 4.4 exts.dart - 扩展方法

```dart
为内置类型添加便利扩展:
- String 扩展
- DateTime 扩展
- List 扩展
- Map 扩展
- num 扩展
等等
```

#### 4.5 平台插件

```
平台特定功能的包装:

├── clipboard_plugin.dart          # 剪贴板操作
├── crypto_plugin.dart             # 加密算法
├── custom_icon.dart               # 自定义图标
├── custom_tab_plugin.dart         # 浏览器标签页
├── deep_link_plugin.dart          # 深链接处理
├── document_plugin.dart           # 文档选择/管理
├── js_eval_plugin.dart            # JavaScript 执行
├── open_setting_plugin.dart       # 打开系统设置
├── paths_plugin.dart              # 路径获取
├── saf_plugin.dart                # Android 存储框架
├── secure_plugin.dart             # 安全存储 (Keychain/Keystore)
├── single_instance_plugin.dart    # 单实例检查
├── supportor_plugin.dart          # 赞助商相关
├── weiss_plugin.dart              # 视图增强
└── win32_plugin.dart              # Windows API 访问
```

## 数据流向分析

### 典型的用户交互流程

```
用户交互 (UI Layer)
     ↓
   Page Widget (接收用户操作)
     ↓
   Page Store (MobX - 处理业务逻辑)
     ↓
   network/api_client.dart (调用 API)
     ↓
   er/fetcher.dart 或 er/hoster.dart (处理网络细节)
     ↓
   Pixiv API Server
     ↓
   响应数据 (JSON)
     ↓
   models/ (反序列化为数据模型)
     ↓
   Store (更新状态)
     ↓
   UI 重建 (Observer Widget)
```

### 图片加载流程

```
UI (需要图片)
     ↓
PixivImage Component
     ↓
pixiv_image.dart (图片加载逻辑)
     ↓
er/hoster.dart (DNS 解析/代理)
     ↓
CacheManager (检查本地缓存)
     ├─ 有缓存 → 直接返回本地图片
     └─ 无缓存 → 网络下载
        ↓
     下载到缓存
        ↓
     解析并显示
```

### 文件下载流程

```
用户点击下载
     ↓
Fetcher (添加到下载队列)
     ↓
Isolate (后台任务)
     ├─ er/hoster.dart (主机解析)
     ├─ 网络请求
     ├─ 进度回调
     └─ Platform Plugin (平台特定保存)
        ↓
     保存到本地
        ↓
     任务完成回调
        ↓
     UI 更新显示
```

## 依赖关系

### 核心依赖

| 依赖 | 用途 | 位置 |
|------|------|------|
| flutter_mobx | 状态管理 | store/ |
| dio | HTTP 客户端 | network/ |
| json_serializable | JSON 序列化 | models/ |
| shared_preferences | 本地存储 | store/user_setting.dart |
| sqflite_common_ffi | 数据库 | main.dart (Windows/Linux) |
| rhttp | 高级网络 | er/hoster.dart, network/api_client.dart |
| cached_network_image | 图片缓存 | component/pixiv_image.dart |
| fluent_ui | Windows 界面 | fluent/ |
| hooks_riverpod | 状态容器 | main.dart |
| bot_toast | 消息提示 | er/toaster.dart |

## 关键设计模式

### 1. MobX 响应式编程

所有状态更新都通过 Store 类完成，UI 自动响应变化。

```dart
class IllustStore = _IllustStore with _$IllustStore;

abstract class _IllustStore with Store {
  @observable
  Illusts? illusts;
  
  @action
  Future<void> fetchIllust(int id) async {
    // 获取数据
  }
}
```

### 2. 单例模式

全局 Store 使用单例，通过 `main.dart` 导出：

```dart
final UserSetting userSetting = UserSetting();
final Fetcher fetcher = Fetcher();
// 在应用其他地方使用：
userSetting.nightMode = true;
```

### 3. 组件组合

复杂的 UI 由多个小组件组合而成：

```dart
// illust_card.dart 组合了：
- PixivImage (图片)
- StarIcon (收藏按钮)
- GestureDetector (交互)
- Card (容器)
```

### 4. 后台隔离 (Isolate)

下载任务运行在单独的 Isolate 中，避免阻塞 UI：

```dart
// fetcher.dart
final isolate = await Isolate.spawn(
  _downloadTask,
  sendPortToChild,
);
```

## 平台特性

### iOS/Android
- 原生风格 Material UI
- 安全存储 (Keychain/Keystore)
- 平台存储 API 集成
- 深链接支持

### Windows
- Fluent UI 主题
- 窗口管理 API
- Win32 系统 API 访问
- 单实例应用

### macOS/Linux
- 平台原生界面元素
- 文件系统访问
- 数据库支持 (sqflite_ffi)

## 扩展建议

### 添加新功能的标准流程

1. **创建数据模型** (`models/new_feature.dart`)
   - 定义 JSON 可序列化结构体

2. **添加 API 方法** (`network/api_client.dart`)
   - 包装对应的 Pixiv API 端点

3. **创建 Store 类** (`store/new_feature_store.dart` 或对应页面)
   - 使用 MobX 管理状态

4. **构建 UI 组件** (`component/` 或 `page/`)
   - 使用 `Observer` Widget 响应状态变化

5. **平台特定处理** (如需要)
   - 实现对应的 Platform Plugin

### 集成到 SwiftUI 项目的考虑

- 复用 `models/` 中的数据结构定义
- 参考 `network/api_client.dart` 的 API 端点实现
- 借鉴 `page/` 的 UI 布局和交互逻辑
- 参考 `store/` 的状态管理模式（对应 SwiftUI 的 `@Observable`）
- 参考 `er/fetcher.dart` 的下载管理实现
- 复用 `er/hoster.dart` 的网络绕过机制

## 总结

Flutter 项目采用了典型的分层架构：
- **UI 层**: 清晰的页面和组件划分，支持多个平台主题
- **业务逻辑层**: 使用 MobX 实现响应式状态管理
- **网络层**: 完整的 API 包装和网络处理
- **数据层**: 丰富的数据模型和本地持久化
- **基础设施**: 完善的平台集成和工具支持

这个架构为 SwiftUI 版本的开发提供了良好的参考，特别是在数据模型、API 设计、状态管理和功能逻辑方面。

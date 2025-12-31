## Plan: Flutter 到 SwiftUI 的渐进式迁移

分阶段迁移一个成熟的 Pixiv 客户端。从最小化功能集开始（登录 + 推荐页），逐步集成网络层、状态管理、UI 组件，最后实现完整功能。核心挑战在于处理网络绕过机制 (TLS/SNI 绕过) 和复杂的图片加载逻辑。

### Steps

1. **建立 SwiftUI 骨架与平台基础** — 在 [Pixiv-SwiftUI/](Pixiv-SwiftUI/) 中创建主应用框架、`SceneDelegate` 初始化、SwiftData 数据库配置。

2. **实现最小网络层** — 封装 `URLSession` 及自定义 DNS 解析器，实现基本的网络请求与响应处理。

3. **迁移数据模型** — 将 [flutter/models/](flutter/models) 中的 `Illusts`、`Account`、`UserSetting` 等转换为 Swift `Codable` 结构体，集成 SwiftData。

4. **实现 MobX 替代品** — 使用 SwiftUI 的 `@Observable` 宏创建 `Store` 类（如 `AccountStore`、`IllustStore`），替代 Flutter 的 MobX 模式。

5. **迁移登录与账号管理** — 实现 [flutter/page/login/](flutter/page/) 的登录流程和多账号切换，连接网络层与状态管理。

6. **构建推荐页 UI** — 使用 `LazyVGrid` 实现 [flutter/component/illust_card.dart](flutter/component/illust_card.dart) 对应的卡片列表，集成图片加载和 R-18 过滤。

7. **添加插画详情页** — 迁移 [flutter/page/picture/](flutter/page/) 中的详情页逻辑，包含评论、收藏、下载功能。

8. **逐步扩展功能** — 按优先级迁移搜索、收藏、历史记录、用户页等模块。

### Further Considerations

1. **网络绕过方案** — 初期采用直接的代理方案，后续逐步迁移到纯 Swift URLSession 配合自定义 DNS。

3. **多平台支持优先级** — Flutter 版支持 iOS/Android/Windows。SwiftUI 版易于支持 iOS/iPadOS/macOS。初期聚焦 iOS，保证对 macOS 的兼容性，后续修正问题。

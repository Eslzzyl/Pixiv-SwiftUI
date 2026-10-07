# 插画瀑布流滚动性能分析

> 编写日期: 2026-06-05
> 分支: `perf/waterfall-scroll`
> 设备: iPhone 17 (26.5.1), 120Hz ProMotion
> 工具: Xcode 26.5 Instruments — SwiftUI 模板 (Core Animation Commits + Time Profiler + FPS Estimate)

---

## 关键数据

### FPS（来自 Core Animation FPS Estimate）

```
录制时长 27 秒
绝大多数时间:  60 FPS
偶尔掉到:     42 FPS, 26 FPS, 57 FPS
从未达到:     120 FPS
```

### CPU Commit 耗时（来自 Core Animation Commits）

| 典型耗时 | 频率 | 含义 |
|---------|------|------|
| ~1ms | 绝大多数帧 | 正常 |
| 9-10ms | 频繁 | **小幅度超出 120Hz 预算 (8.33ms)** |
| 17-42ms | 偶尔 (3次) | 大掉帧 |

### GPU Render 耗时（来自 GPU Hitches）

| 典型耗时 | 含义 |
|---------|------|
| 8.6-9.4ms | GPU 渲染也频繁超出 120Hz 预算 |

**结论**: CPU 提交 + GPU 渲染合计每帧约 9-10ms，刚好卡在 120Hz 门槛 (8.33ms) 之外。

---

## 根因分析

### 直接原因: 帧时间略微超过 120Hz 预算

- 120Hz ProMotion 每帧预算: **8.33ms**
- App 实际帧时间: **9-10ms**
- 超出约 1-2ms → 帧被跳过 → 显示器在 60Hz/120Hz 间反复切换 → 感知为"抖动"
- 低电量模式 (60Hz 锁定) 下: 预算 16.67ms，实际 9-10ms → 流畅

### 深层原因

#### 1. LazyVStack + KFImage 已知兼容问题

- Kingfisher Issue #2490 "KFImage will shaking in SwiftUI LazyVStack ScrollView" (未关闭)
- KFImage 内部有 ZStack 包裹 (PR #1840)，作为 SwiftUI lazy container identity 的工作区
- 每个 KFImage 在占位态和加载态之间有内部视图结构变化，触发 LazyVStack 高度重协商
- LazyVStack 不具备 cell reuse 机制，视图一旦创建就常驻

#### 2. 卡片视图层级复杂

每张 `IllustCard` 视图树深度约 15 层:

```
VStack
  ZStack (thumbnailImage + badge overlays)
    CachedAsyncImage
      Group
        KFImage (内置 ZStack)
          placeholderView / loadedImage
    HStack (manga/ugoira/AI badges)
    Text (page count)
    HStack (bookmark count)
  HStack
    VStack (title + user name)
    Button (bookmark)
  .cornerRadius(16)
  .shadow(...)
  .contextMenu
```

12 张可见卡片 × 15 层 = 约 180 个视图节点参与每帧提交。

#### 3. DownsamplingImageProcessor 造成 CPU 尖峰

- `DownsamplingImageProcessor.process()` 单次耗时 **39ms**
- 发生于新图片加载时，虽在后台队列，但竞争系统资源
- 对应 Instruments 中看到的 42ms CPU commit 尖峰

---

## 已应用的优化

| # | 改动 | 文件 | 预期收益 |
|---|------|------|----------|
| 1 | WaterfallGrid 增量列更新（只追加新元素，不重算已有列） | WaterfallGrid.swift | 降低翻页时 CPU 占用，保持 ForEach identity |
| 2 | 移除 WaterfallGrid 内嵌 GeometryReader | WaterfallGrid.swift | 减少布局传递次数 |
| 3 | KFImage 移除 `.fade(duration: 0.5)` | Helpers.swift | 减少 CA 事务，消除滚动时额外动画开销 |
| 4 | KFImage 添加 `.cancelOnDisappear(true)` | Helpers.swift | 离屏时取消下载任务 |
| 5 | Kingfisher 8.6.2 → 8.9.0 | Package.resolved | 获取 asyncCacheTypeCheck API |
| 6 | KFImage 启用 `asyncCacheTypeCheck` | Helpers.swift | 将同步 disk stat() 移出主线程 |
| 7 | CachedAsyncImage 去掉外层 ZStack | Helpers.swift | 减少 GPU 合成层级 |
| 8 | shouldBlur O(n) 数组搜索 → O(1) 字典查询 | RecommendView.swift, UpdatesPage.swift | 降低卡片 body 求值开销 |
| 9 | NavigationLink → onTapGesture | RecommendView.swift, UpdatesPage.swift | 减少视图树节点 |
| 10 | 徽章 .ultraThinMaterial → .black.opacity(0.25) | IllustCard.swift | 移除 48 个 GPU 实时模糊层 |
| 11 | 移除 .compositingGroup() | IllustCard.swift | 减少离屏 render pass |
| 12 | CachedAsyncImage 加显式 .frame(width:height:) | IllustCard.swift | 固定 KFImage 容器尺寸，稳定 LazyVStack |
| 13 | Kingfisher 内存缓存 100MB → 200MB | CacheConfig.swift | 减少缓存驱逐导致的重复解码 |

---

## 剩余瓶颈

### 帧时间分布 (估算)

```
每帧总时间 ~9-10ms
  ├─ CPU Commit:   ~4-5ms
  │   ├─ SwiftUI view diffing & layout:  ~1-2ms
  │   ├─ KFImage 内部状态管理:          ~1-2ms
  │   └─ LazyVStack 视图创建:           ~1-2ms (仅新卡片出现时)
  ├─ GPU Render:    ~4-5ms
  │   ├─ 视图树合成:       ~1-2ms
  │   ├─ 阴影 (12 张卡片): ~1-2ms
  │   └─ 图片合成:         ~1-2ms
  └─ 其他:           ~0-1ms
```

需要从 9-10ms 压到 **8ms 以内**，即削减约 **2ms**。

---

## 可行的下一步方向

### 方向 A: 替换 KFImage 为轻量级加载器

KFImage 内部持有大量状态 (ImageBinder、ImageContext、StateObject 等)。在 12 张卡片同时可见的场景下，这些内部视图和观察者的维护开销不可忽略。

可能的方案:
- 使用自定义 `AsyncImage` 替代 KFImage，基于 `URLSession` + 手动缓存
- 减少每个图片加载器的内部状态管理开销
- 预估节省: 0.5-1ms per frame

### 方向 B: 减少卡片视图层数

每张卡片 15 层，如果能压到 8-10 层:
- 徽章改用 `Canvas` 绘制而非 SwiftUI View
- 合并重叠的修饰符 (cornerRadius、shadow、clip)
- 移除 `.contextMenu` (条件编译，仅保留 macOS)
- 预估节省: 0.5-1ms per frame

### 方向 C: 瀑布流改用 List + UICollectionViewLayout

`List` 底层使用 `UICollectionView`，具备真正的 cell reuse:
- 离屏视图被回收，内存有界
- 不存在 LazyVStack 的视图常驻问题
- 消除 KFImage + LazyVStack 的已知兼容问题 #2490
- 需要实现自定义 `UICollectionViewLayout` 实现瀑布流
- 预估节省: 1-3ms per frame

### 方向 D: 移除卡片阴影

`.shadow()` 为每张卡片增加离屏 render pass:
- 12 张卡片 × 1 pass = 12 个离屏 pass/帧
- 如果改用预渲染阴影图片覆盖 (pre-rendered shadow PNG)，无需离屏 pass
- 预估节省: 0.5-1ms per frame

---

## Instruments 使用说明

### SwiftUI 模板 (推荐)

1. Xcode → Product → Profile (⌘I)
2. 选择 **SwiftUI** 模板
3. 包含: Core Animation Commits + View Body + View Properties + Time Profiler
4. 在目标页面滑动录制

### 查看关键指标

- **Core Animation Commits**: 每帧提交耗时。红色 >8ms → 120Hz 掉帧
- **View Body**: body 求值耗时。频繁 >2ms → 视图在重建
- **GPU Hitches**: GPU 渲染耗时。>8.33ms → GPU 瓶颈
- **Time Profiler**: 主线程调用栈。搜索 `CA::Transaction::commit` 可定位渲染提交耗时

### CLI 导出

```bash
# 列出 trace 内容
xcrun xctrace export --input run.trace --toc

# 导出 FPS 数据
xcrun xctrace export --input run.trace --xpath \
  '/trace-toc/run[@number="1"]/data/table[@schema="core-animation-fps-estimate"]'

# 导出 Commit 耗时
xcrun xctrace export --input run.trace --xpath \
  '/trace-toc/run[@number="1"]/data/table[@schema="coreanimation-commit-summary"]'

# 导出 GPU Hitch
xcrun xctrace export --input run.trace --xpath \
  '/trace-toc/run[@number="1"]/data/table[@schema="hitches-gpu"]'
```

## 2026-10-07 能耗优化重构

本节记录本次实现与校验。前文保留历史分析。

### 实现

|模块|改动|
|---|---|
|`WaterfallGrid`|通过 `StateObject` 保留布局模型；保留类型化 ID、元素高度、所属列和累计高度。追加执行 O(n) 前缀检查和 O(k × c) 分配；已有比例变化更新累计高度，已有列成员保持。|
|插画详情导航|通过 `StateObject` 的 autoclosure 创建并保留目标与会话。Session 初始化统一完成首个 ID 对象去重与选中项补充；上下文 provider 持续读取当前数据。|
|推荐、动态和详情信息|推荐区域、网格、分页以及详情控制使用独立 View 类型。分页子 View 直接读取分页状态；动态筛选结果由保留的 `UpdatesFeedProjection` 提供。|
|图片处理|新增 `PixivDownsamplingImageProcessor`。Data 输入沿用 Kingfisher ImageIO 路径；静态位图输入直接绘制缩放。处理器 identifier 与原有尺寸标识一致。|
|源图缓存|无处理器预取及离线收藏预加载使用 `preferCacheOriginalData = true`。处理后的缩略图继续使用默认序列化器。|
|滚动、几何和阴影|滚动上一值使用普通引用对象；可见状态、宽度、列数与图片比例按有效变化赋值。阴影路径按尺寸和圆角更新，颜色按当前 traits/appearance 解析。|

UIKit 输出使用请求的 scale，方向为 `.up`。macOS 沿用 Kingfisher 的 `NSImage(cgImage:size: .zero)` 像素尺寸包装；请求 scale 参与目标像素尺寸计算。动画图、无 CGImage 输入和转换失败继续使用 Kingfisher 原处理路径。

### 已执行的无界面校验

- 实际布局实现：初始列 `[1,4,5,6]`、`[2,3]`，追加、删除、重排、列数变化、空数据、零列、无比例模式、比例变化后的追加和重复通知。
- 实际 Session/Target 实现：空上下文、重复 ID、首个对象保留、选中项补充、活上下文 provider、分页状态和会话 UUID。
- 实际网格与分页 body 的 Observation 依赖：分页 loading/error/nextURL 变化与已有网格更新隔离；筛选变化更新动态投影与模糊字典。临时校验程序使用隔离数据与界面依赖替身。
- UIKit/AppKit 实际图片处理器：JPEG、透明 PNG、sRGB/Display P3、EXIF 1–8、长图与小源图、Data 与已解码图片输入、请求 scale 1/2/3。UIKit 另核对输入 scale 1/2/3、动画图与无 CGImage 输入。1000×4000 图片在 size 400×300、scale 1 时输出 100×400 像素。
- Kingfisher 临时磁盘缓存：源图字节保持、旧尺寸标识缩略图、源图命中、冷 Data provider、处理后缩略图持久化、离线原图和过期缓存。所有缓存位于独立临时目录。
- 实际滚动事件处理：`[0,-21,-45,-20,0]` 对应 `[显示,隐藏,隐藏,显示,显示]`；严格 ±20 阈值及连续小位移。
- UIKit/AppKit 阴影属性：路径复用、尺寸和圆角更新、样式属性更新、动态颜色解析。UIKit 使用显式 traits 输入；实际窗口中的主题切换待手动检查。

### 手动验收

导航 identity、返回转场、VoiceOver、分页与登录事件、收藏/关注同步、低清向目标画质升级、全屏与多页比例、GIF/Ugoira、缩放、菜单、glass、淡入及真实阴影效果待手动检查。应用启动、smoke test、物理设备操作及新 trace 录制均未执行。

能耗结果待新的匹配真机录制。受控场景目标保持：系统耗电率中位数达到官方的 110% 以内，或本项目匹配基线的系统耗电率及归一化总 CPU 降低至少 25%、主线程 CPU 降低至少 30%。每组五次录制使用一致账号、作品、画质、亮度、缓存状态和操作时序。

### 编译验收

三项构建均使用独立 DerivedData，退出码均为 0，并输出 `BUILD SUCCEEDED`：

|构建|配置|签名|
|---|---|---|
|generic iOS|Release，项目现有 `-O`|`CODE_SIGNING_ALLOWED=NO`|
|iPhone 17 Simulator|Debug|项目现有配置|
|macOS|Debug|`CODE_SIGNING_ALLOWED=NO`|

构建记录保存在 `/tmp/pixiv-energy-verify.OOz4p7/` 的 `ios-release-build.log`、`ios-simulator-build.log` 与 `macos-build.log`。本次源码诊断已处理；三项构建剩余相同提示：`Metadata extraction skipped, no AppIntents.framework dependency found`。

临时校验程序已删除，项目未新增测试 target。应用启动与能耗测量仍由用户手动执行。


# 插画瀑布流组件 (Illust Waterfall)

本文档分析了项目中的插画瀑布流组件 `WaterfallGrid` 的结构、实现原理及在各页面中的使用注意事项。

## 组件概览

- **文件路径**: `Pixiv-SwiftUI/Shared/Components/WaterfallGrid.swift`
- **核心功能**: 提供多列瀑布流布局，支持基于如图片长宽比（Aspect Ratio）的智能排版（最短列优先）。
- **适用场景**: 插画推荐、搜索结果、收藏列表、用户作品集等。

## 架构设计

`WaterfallGrid` 本身不包含滚动容器，它设计为嵌入在外部的 `ScrollView` 中使用。

### 视图层级

```swift
ScrollView {         // 外部滚动容器
    LazyVStack {     // 外部虚拟容器（推荐）
        // 头部组件...
        
        WaterfallGrid(...) // 瀑布流组件本体
        
        // 底部加载更多...
    }
}
```

### 内部结构

组件内部使用了 **HStack of LazyVStacks** 的结构来模拟瀑布流：

```swift
VStack {
    // 1. 宽度测量器 (GeometryReader)
    // 用于动态获取容器宽度，响应屏幕旋转或窗口缩放

    // 2. 列布局
    HStack(alignment: .top, spacing: spacing) {
        ForEach(0..<columnCount) { columnIndex in
            LazyVStack(spacing: spacing) {
                // 当前列的数据项
                ForEach(columns[columnIndex]) { item in
                    content(item, safeColumnWidth)
                }
            }
            .frame(width: safeColumnWidth)
        }
    }
}
```

## 布局算法

组件使用 **最短列优先 (Shortest Column First)** 的贪心算法来分配数据项，以保证瀑布流底部的相对平整。

1.  **输入**: 数据集 `Data`，列数 `columnCount`，以及可选的 `heightProvider`。
2.  **高度计算**:
    -   如果未提供 `heightProvider`，退化为简单的 `index % columnCount` 取模分配。
    -   如果提供了 `heightProvider` (通常返回 `width / height` 长宽比)，则计算归一化高度 `itemHeight = 1.0 / aspectRatio`。
3.  **分配逻辑**:
    -   维护一个 `columnHeights` 数组记录每列当前高度。
    -   遍历数据项，每次将新项追加到当前高度最小的那一列 (`minIndex`)。
    -   更新该列高度。

### 代码位置

```swift
// Pixiv-SwiftUI/Shared/Components/WaterfallGrid.swift

private var columns: [[Data.Element]] {
    // ... 初始化 ...
    
    // 智能分配
    for item in data {
        if let minIndex = columnHeights.indices.min(by: { columnHeights[$0] < columnHeights[$1] }) {
            result[minIndex].append(item)
            // ... 更新高度 ...
        }
    }
    return result
}
```

## 骨架屏 (Skeleton)

- **文件路径**: `Pixiv-SwiftUI/Shared/Components/SkeletonIllustCard.swift`
- **组件**: `SkeletonIllustWaterfallGrid`
- **注意**: 骨架屏组件 **独立实现** 了类似的网格布局逻辑，并没有复用 `WaterfallGrid`。
    -   **维护风险**: 如果修改了 `WaterfallGrid` 的 `spacing` 或宽度计算逻辑，必须同步修改 `SkeletonIllustWaterfallGrid`，否则会导致加载状态切换到内容状态时布局跳动（Layout Shift）。

## 使用注意事项

### 1. 外部容器

由于 `WaterfallGrid` 内部使用 `LazyVStack` 作为列容器，它能够处理大量数据的懒加载渲染。但是，如果在此组件上方或下方有其他内容，建议将其包裹在外部的 `LazyVStack` 中，以避免外部容器在初始化时一次性计算整个瀑布流的高度。

**正确示例**:

```swift
ScrollView {
    LazyVStack { // 使用 LazyVStack 包裹
        HeaderView()
        
        WaterfallGrid(...)
        
        if isLoading {
            ProgressView() // 只有滚动到底部才加载
        }
    }
}
```

### 2. 加载更多 (Infinite Scroll)

不要将 `loadMore` 触发器放在 `WaterfallGrid` 内部。应将其作为 `WaterfallGrid` 的兄弟视图放置在外部容器的底部。

### 3. macOS 与 iOS 的列数差异

项目通常根据平台动态调整列数：
- **iOS**: 通常 2 列。
- **macOS/iPad**: 根据宽度动态调整，通常 4 列或更多。
- 使用 `.responsiveGridColumnCount` 修饰符（如果存在）或在父视图中计算 `dynamicColumnCount`。

### 4. 性能优化

- `columns` 属性是计算属性 (Computed Property)。每当 `View` 刷新时都会重新计算布局。
- 在数据量极大（如数千项）时，主线程计算布局可能会造成掉帧。但在本应用的分页场景（通常 < 200 项）下，性能是可以接受的。
- 之前曾尝试使用 `@State` 缓存列数据，但为了保证数据一致性（Data Consistency）和响应式更新，目前回退到了实时计算。

## Git 历史演变

1.  **初始版本**: 简单的取模 (`index % columnCount`) 分配，不支持长宽比感知。
2.  **性能优化尝试 (127c478)**: 引入 `@State` 缓存 `columns`，试图通过 `onChange` 更新。
3.  **算法升级 (Latest)**: 引入 `heightProvider` 接口，实现最短列优先算法，实现了真正的参差不齐的瀑布流效果，更美观。

## 常见问题排查

- **布局跳动**: 检查 `SkeletonIllustWaterfallGrid` 的间距设置是否与 `WaterfallGrid` 一致。
- **加载更多不触发**: 检查外部是否误用了 `VStack` 代替 `LazyVStack`，导致底部视图被提前初始化。
- **图片高度异常**: 确保 `heightProvider` 返回的 `aspectRatio` 不为 0 或 NaN。


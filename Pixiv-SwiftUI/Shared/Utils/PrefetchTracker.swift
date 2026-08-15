import Foundation

/// 预取进度追踪器（引用类型，避免 @State 触发不必要的视图重绘）
@MainActor
public final class PrefetchTracker {
    public var prefetchedUpToIndex: Int = 0

    public init() {}
}

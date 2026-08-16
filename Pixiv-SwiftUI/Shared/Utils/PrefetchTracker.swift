import Foundation
import Kingfisher

/// 预取进度追踪器（引用类型，避免 @State 触发不必要的视图重绘）
@MainActor
public final class PrefetchTracker {
    public var nextPrefetchIndex: Int = 0

    public init() {}
}

@MainActor
final class ImagePrefetchCoordinator {
    static let shared = ImagePrefetchCoordinator()

    private var activePrefetcher: ImagePrefetcher?
    private let maxConcurrentDownloads = 2

    private init() {}

    func start(sources: [Kingfisher.Source]) {
        activePrefetcher?.stop()

        guard !sources.isEmpty else {
            activePrefetcher = nil
            return
        }

        let prefetcher = ImagePrefetcher(sources: sources, options: [
            .requestModifier(PixivImageLoader.shared),
            .alsoPrefetchToMemory,
        ])
        prefetcher.maxConcurrentDownloads = maxConcurrentDownloads
        activePrefetcher = prefetcher
        prefetcher.start()
    }

    func stop() {
        activePrefetcher?.stop()
        activePrefetcher = nil
    }
}

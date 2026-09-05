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
    private var pendingSources: [Kingfisher.Source] = []
    private var queuedKeys = Set<String>()
    private var generation: UInt = 0
    private let maxConcurrentDownloads = 2

    private init() {}

    func enqueue(sources: [Kingfisher.Source], prioritised: Bool = false) {
        var newSources: [Kingfisher.Source] = []
        for source in sources where queuedKeys.insert(source.cacheKey).inserted {
            newSources.append(source)
        }

        guard !newSources.isEmpty else { return }
        if prioritised {
            pendingSources.insert(contentsOf: newSources, at: 0)
        } else {
            pendingSources.append(contentsOf: newSources)
        }
        startNextBatchIfNeeded()
    }

    func stop() {
        generation &+= 1
        activePrefetcher?.stop()
        activePrefetcher = nil
        pendingSources.removeAll()
        queuedKeys.removeAll()
    }

    private func startNextBatchIfNeeded() {
        guard activePrefetcher == nil, !pendingSources.isEmpty else { return }

        let batchCount = min(maxConcurrentDownloads, pendingSources.count)
        let batch = Array(pendingSources.prefix(batchCount))
        pendingSources.removeFirst(batchCount)
        let batchKeys = Set(batch.map(\.cacheKey))
        let currentGeneration = generation

        let prefetcher = ImagePrefetcher(
            sources: batch,
            options: [
                .requestModifier(PixivImageLoader.shared),
                .alsoPrefetchToMemory,
            ],
            completionHandler: { [weak self] _, _, _ in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == currentGeneration else { return }
                    self.activePrefetcher = nil
                    self.queuedKeys.subtract(batchKeys)
                    self.startNextBatchIfNeeded()
                }
            }
        )
        prefetcher.maxConcurrentDownloads = maxConcurrentDownloads
        activePrefetcher = prefetcher
        prefetcher.start()
    }
}

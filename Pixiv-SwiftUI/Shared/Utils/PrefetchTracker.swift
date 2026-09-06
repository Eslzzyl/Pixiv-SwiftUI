import Foundation
import Kingfisher

enum ImageRequestPriority {
    nonisolated static let background = URLSessionTask.lowPriority
    nonisolated static let prefetch = (URLSessionTask.lowPriority + URLSessionTask.defaultPriority) / 2
    nonisolated static let visible = URLSessionTask.highPriority
}

/// 预取进度追踪器（引用类型，避免 @State 触发不必要的视图重绘）
@MainActor
public final class PrefetchTracker {
    public var nextPrefetchIndex: Int = 0

    public init() {}
}

@MainActor
final class ImagePrefetchCoordinator {
    static let shared = ImagePrefetchCoordinator()

    private struct PendingSource {
        let source: Kingfisher.Source
        let order: UInt64
        var priority: Float
    }

    private var activePrefetcher: ImagePrefetcher?
    private var pendingSources: [PendingSource] = []
    private var activeKeys = Set<String>()
    private var nextOrder: UInt64 = 0
    private var generation: UInt = 0
    private let maxConcurrentDownloads = 2

    private init() {}

    func enqueue(sources: [Kingfisher.Source], priority: Float = ImageRequestPriority.background) {
        let clampedPriority = min(max(priority, URLSessionTask.lowPriority), URLSessionTask.highPriority)

        for source in sources {
            if let index = pendingSources.firstIndex(where: { $0.source.cacheKey == source.cacheKey }) {
                if clampedPriority > pendingSources[index].priority {
                    pendingSources[index].priority = clampedPriority
                }
                continue
            }

            guard !activeKeys.contains(source.cacheKey) else { continue }
            pendingSources.append(
                PendingSource(
                    source: source,
                    order: nextOrder,
                    priority: clampedPriority
                )
            )
            nextOrder &+= 1
        }

        pendingSources.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.order < rhs.order
        }
        startNextBatchIfNeeded()
    }

    func removePending(cacheKey: String) {
        pendingSources.removeAll { $0.source.cacheKey == cacheKey }
        startNextBatchIfNeeded()
    }

    func stop() {
        generation &+= 1
        activePrefetcher?.stop()
        activePrefetcher = nil
        pendingSources.removeAll()
        activeKeys.removeAll()
    }

    private func startNextBatchIfNeeded() {
        guard activePrefetcher == nil, !pendingSources.isEmpty else { return }

        let batchPriority = pendingSources[0].priority
        var batchCount = 0
        for pendingSource in pendingSources {
            guard pendingSource.priority == batchPriority,
                  batchCount < maxConcurrentDownloads else { break }
            batchCount += 1
        }
        let batch = Array(pendingSources.prefix(batchCount))
        pendingSources.removeFirst(batchCount)
        let batchKeys = Set(batch.map { $0.source.cacheKey })
        activeKeys.formUnion(batchKeys)
        let currentGeneration = generation

        let prefetcher = ImagePrefetcher(
            sources: batch.map(\.source),
            options: [
                .requestModifier(PixivImageLoader.shared),
                .alsoPrefetchToMemory,
                .downloadPriority(batchPriority),
            ],
            completionHandler: { [weak self] _, _, _ in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == currentGeneration else { return }
                    self.activePrefetcher = nil
                    self.activeKeys.subtract(batchKeys)
                    self.startNextBatchIfNeeded()
                }
            }
        )
        prefetcher.maxConcurrentDownloads = maxConcurrentDownloads
        activePrefetcher = prefetcher
        prefetcher.start()
    }
}

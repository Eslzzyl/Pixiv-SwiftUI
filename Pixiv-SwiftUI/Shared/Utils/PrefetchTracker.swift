import Foundation
import Kingfisher
import os.log

enum ImageRequestPriority {
    nonisolated static let background = URLSessionTask.lowPriority
    nonisolated static let prefetch = (URLSessionTask.lowPriority + URLSessionTask.defaultPriority) / 2
    nonisolated static let visible = URLSessionTask.highPriority
}

actor PixivVisibleImageActivity {
    static let shared = PixivVisibleImageActivity()

    private var activeCount = 0
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []

    func begin() {
        activeCount += 1
    }

    func end() {
        activeCount = max(0, activeCount - 1)
        guard activeCount == 0, !idleWaiters.isEmpty else { return }
        let waiters = idleWaiters
        idleWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func waitUntilIdle() async {
        guard activeCount > 0 else { return }
        await withCheckedContinuation { continuation in
            idleWaiters.append(continuation)
        }
    }
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
    private var scheduledStartTask: Task<Void, Never>?
    private let maxConcurrentDownloads = 2

    private init() {}

    func enqueue(sources: [Kingfisher.Source], priority: Float = ImageRequestPriority.background) {
        let clampedPriority = min(max(priority, URLSessionTask.lowPriority), URLSessionTask.highPriority)
        var addedCount = 0

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
            addedCount += 1
            nextOrder &+= 1
        }

        pendingSources.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.order < rhs.order
        }
        let pendingCountAfterEnqueue = pendingSources.count
        let activePrefetcherCount = activePrefetcher == nil ? 0 : 1
        let requestRole = PixivImageRequestLogContext.role(for: clampedPriority)
        Logger.network.debug(
            "image prefetch enqueue requested=\(sources.count) added=\(addedCount) role=\(requestRole, privacy: .public) priority=\(clampedPriority) pending=\(pendingCountAfterEnqueue) active=\(activePrefetcherCount)"
        )
        startNextBatchIfNeeded()
    }

    func removePending(cacheKey: String) {
        let pendingCount = pendingSources.count
        pendingSources.removeAll { $0.source.cacheKey == cacheKey }
        let removedCount = pendingCount - pendingSources.count
        if removedCount > 0 {
            let pendingCountAfterRemoval = pendingSources.count
            Logger.network.debug(
                "image prefetch removed count=\(removedCount) pending=\(pendingCountAfterRemoval)"
            )
        }
        if pendingSources.isEmpty {
            scheduledStartTask?.cancel()
            scheduledStartTask = nil
        }
        startNextBatchIfNeeded()
    }

    func stop() {
        let pendingCount = pendingSources.count
        let hadActivePrefetcher = activePrefetcher != nil
        generation &+= 1
        scheduledStartTask?.cancel()
        scheduledStartTask = nil
        activePrefetcher?.stop()
        activePrefetcher = nil
        pendingSources.removeAll()
        activeKeys.removeAll()
        if pendingCount > 0 || hadActivePrefetcher {
            Logger.network.debug(
                "image prefetch stopped pending=\(pendingCount) active=\(hadActivePrefetcher ? 1 : 0)"
            )
        }
    }

    private func startNextBatchIfNeeded() {
        guard activePrefetcher == nil, !pendingSources.isEmpty else { return }
        guard scheduledStartTask == nil else { return }

        let currentGeneration = generation
        let delay = Duration.milliseconds(200)
        let pendingCount = pendingSources.count
        Logger.network.debug(
            "image prefetch waiting for idle start delayMs=200 pending=\(pendingCount)"
        )
        scheduledStartTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard let self, self.generation == currentGeneration else { return }
            let visibleWaitStartedAt = DispatchTime.now().uptimeNanoseconds
            await PixivVisibleImageActivity.shared.waitUntilIdle()
            let visibleWaitMs = (DispatchTime.now().uptimeNanoseconds - visibleWaitStartedAt) / 1_000_000
            guard !Task.isCancelled, self.generation == currentGeneration else { return }
            self.scheduledStartTask = nil
            self.startNextBatch(visibleWaitMs: visibleWaitMs)
        }
    }

    private func startNextBatch(visibleWaitMs: UInt64) {
        guard activePrefetcher == nil, !pendingSources.isEmpty else { return }

        let batchPriority = pendingSources[0].priority
        let batchRole = PixivImageRequestLogContext.role(for: batchPriority)
        var selectedCount = 0
        for pendingSource in pendingSources {
            guard pendingSource.priority == batchPriority,
                  selectedCount < maxConcurrentDownloads else { break }
            selectedCount += 1
        }
        let batch = Array(pendingSources.prefix(selectedCount))
        let batchCount = batch.count
        pendingSources.removeFirst(batchCount)
        let batchKeys = Set(batch.map { $0.source.cacheKey })
        activeKeys.formUnion(batchKeys)
        let currentGeneration = generation
        let pendingCountAfterStart = pendingSources.count
        let concurrency = maxConcurrentDownloads
        Logger.network.info(
            "image prefetch batch started count=\(batchCount) role=\(batchRole, privacy: .public) priority=\(batchPriority) pending=\(pendingCountAfterStart) concurrency=\(concurrency) idleDelayMs=200 visibleWaitMs=\(visibleWaitMs)"
        )

        let prefetcher = ImagePrefetcher(
            sources: batch.map(\.source),
            options: [
                .requestModifier(PixivImageLoader.shared),
                .alsoPrefetchToMemory,
                .downloadPriority(batchPriority),
            ],
            completionHandler: { [weak self] skippedResources, failedResources, completedResources in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == currentGeneration else { return }
                    self.activePrefetcher = nil
                    self.activeKeys.subtract(batchKeys)
                    Logger.network.info(
                        "image prefetch batch completed count=\(batchCount) role=\(batchRole, privacy: .public) completed=\(completedResources.count) failed=\(failedResources.count) skipped=\(skippedResources.count) pending=\(self.pendingSources.count)"
                    )
                    self.startNextBatchIfNeeded()
                }
            }
        )
        prefetcher.maxConcurrentDownloads = maxConcurrentDownloads
        activePrefetcher = prefetcher
        prefetcher.start()
    }
}

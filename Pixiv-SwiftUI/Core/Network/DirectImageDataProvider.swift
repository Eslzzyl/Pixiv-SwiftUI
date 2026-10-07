import Foundation
import Kingfisher
import os.log

enum PixivImageRequestLogContext {
    nonisolated static func kind(for url: URL) -> String {
        if PixivNetworkConfiguration.isOriginalImageURL(url) {
            return "original"
        }
        if url.path.contains("/c/250x250_") || url.path.contains("/c/540x540_") {
            return "thumbnail"
        }
        if url.path.contains("/c/") {
            return "list-large"
        }
        return "image"
    }

    nonisolated static func role(for priority: Float) -> String {
        if priority <= ImageRequestPriority.background {
            return "background"
        }
        if priority <= ImageRequestPriority.prefetch {
            return "prefetch"
        }
        if priority >= ImageRequestPriority.visible {
            return "visible"
        }
        return "default"
    }

    nonisolated static func key(for url: URL) -> String {
        String(url.absoluteString.hashValue, radix: 16)
    }

    nonisolated static func isCancellation(_ error: Error) -> Bool {
        if Task.isCancelled || error is CancellationError {
            return true
        }
        if let urlError = error as? URLError {
            return urlError.code == .cancelled
        }
        return false
    }
}

actor PixivImageRequestPriorityState {
    private var priority: Float

    init(priority: Float) {
        self.priority = priority
    }

    func promote(to priority: Float) {
        self.priority = max(self.priority, priority)
    }

    func currentPriority() -> Float {
        priority
    }
}

private final class PixivImageRequestWaiter: @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var continuation: CheckedContinuation<Data, Error>?
    private nonisolated(unsafe) var hasFinished = false
    private nonisolated(unsafe) var pendingResult: Result<Data, Error>?

    nonisolated func install(_ continuation: CheckedContinuation<Data, Error>) -> Bool {
        var pendingResult: Result<Data, Error>?
        lock.lock()
        if hasFinished {
            pendingResult = self.pendingResult
            self.pendingResult = nil
        } else {
            self.continuation = continuation
        }
        lock.unlock()

        if let pendingResult {
            continuation.resume(with: pendingResult)
            return false
        }
        return true
    }

    nonisolated func finish(_ result: Result<Data, Error>) {
        var continuation: CheckedContinuation<Data, Error>?
        lock.lock()
        guard !hasFinished else {
            lock.unlock()
            return
        }
        hasFinished = true
        if let storedContinuation = self.continuation {
            continuation = storedContinuation
            self.continuation = nil
        } else {
            pendingResult = result
        }
        lock.unlock()
        continuation?.resume(with: result)
    }
}

private actor PixivImageRequestCoordinator {
    static let shared = PixivImageRequestCoordinator()
    static let cancellationGraceMilliseconds: Int64 = 400

    private struct Entry {
        let id: UUID
        let task: Task<Data, Error>
        let priorityState: PixivImageRequestPriorityState
        var priority: Float
        var waiterCount: Int
        let allowsCancellationGrace: Bool
        var cancellationGraceTask: Task<Void, Never>?
    }

    private var entries: [String: Entry] = [:]

    func data(
        for key: String,
        imageKey: String,
        priority: Float,
        allowsCancellationGrace: Bool,
        operation: @escaping @Sendable (PixivImageRequestPriorityState) async throws -> Data
    ) async throws -> Data {
        let entry: Entry
        if var existing = entries[key] {
            let existingPriority = existing.priority
            let reusedCancellationGrace = existing.waiterCount == 0 && existing.cancellationGraceTask != nil
            existing.cancellationGraceTask?.cancel()
            existing.cancellationGraceTask = nil
            existing.waiterCount += 1
            if priority > existing.priority {
                existing.priority = priority
                await existing.priorityState.promote(to: priority)
                Logger.network.info(
                    "image request promoted imageKey=\(imageKey, privacy: .public) from=\(PixivImageRequestLogContext.role(for: existingPriority), privacy: .public) to=\(PixivImageRequestLogContext.role(for: priority), privacy: .public)"
                )
            }
            entries[key] = existing
            if reusedCancellationGrace {
                Logger.network.info(
                    "image request cancellation grace reused imageKey=\(imageKey, privacy: .public) graceMs=\(Self.cancellationGraceMilliseconds)"
                )
            }
            Logger.network.debug(
                "image request coalesced imageKey=\(imageKey, privacy: .public) existingRole=\(PixivImageRequestLogContext.role(for: existingPriority), privacy: .public) requestedRole=\(PixivImageRequestLogContext.role(for: priority), privacy: .public)"
            )
            entry = existing
        } else {
            let priorityState = PixivImageRequestPriorityState(priority: priority)
            let entryID = UUID()
            let task = Task.detached(priority: Self.taskPriority(for: priority)) {
                try await operation(priorityState)
            }
            let newEntry = Entry(
                id: entryID,
                task: task,
                priorityState: priorityState,
                priority: priority,
                waiterCount: 1,
                allowsCancellationGrace: allowsCancellationGrace,
                cancellationGraceTask: nil
            )
            entries[key] = newEntry
            entry = newEntry
        }

        do {
            let data = try await awaitTask(entry.task)
            releaseWaiter(
                key: key,
                imageKey: imageKey,
                entryID: entry.id,
                cancelled: false
            )
            return data
        } catch {
            releaseWaiter(
                key: key,
                imageKey: imageKey,
                entryID: entry.id,
                cancelled: PixivImageRequestLogContext.isCancellation(error)
            )
            throw error
        }
    }

    private func awaitTask(_ task: Task<Data, Error>) async throws -> Data {
        let waiter = PixivImageRequestWaiter()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                guard waiter.install(continuation) else { return }
                Task.detached {
                    do {
                        waiter.finish(.success(try await task.value))
                    } catch {
                        waiter.finish(.failure(error))
                    }
                }
            }
        }, onCancel: {
            waiter.finish(.failure(CancellationError()))
        })
    }

    private func releaseWaiter(
        key: String,
        imageKey: String,
        entryID: UUID,
        cancelled: Bool
    ) {
        guard var entry = entries[key], entry.id == entryID else { return }
        entry.waiterCount = max(0, entry.waiterCount - 1)

        if cancelled, entry.waiterCount > 0 {
            Logger.network.debug(
                "image request waiter cancelled imageKey=\(imageKey, privacy: .public) remainingWaiters=\(entry.waiterCount)"
            )
        }

        if cancelled, entry.waiterCount == 0 {
            if entry.allowsCancellationGrace {
                if entry.cancellationGraceTask == nil {
                    let graceMilliseconds = Self.cancellationGraceMilliseconds
                    entry.cancellationGraceTask = Task { [weak self] in
                        do {
                            try await Task.sleep(for: .milliseconds(graceMilliseconds))
                        } catch {
                            return
                        }
                        await self?.cancelAfterGrace(
                            key: key,
                            imageKey: imageKey,
                            entryID: entryID
                        )
                    }
                    Logger.network.info(
                        "image request cancellation grace scheduled imageKey=\(imageKey, privacy: .public) graceMs=\(graceMilliseconds)"
                    )
                }
            } else {
                entry.task.cancel()
                Logger.network.debug(
                    "image request coalesced task cancelled imageKey=\(imageKey, privacy: .public) remainingWaiters=0"
                )
            }
        }

        if entry.waiterCount == 0, entry.cancellationGraceTask == nil {
            entries.removeValue(forKey: key)
        } else {
            entries[key] = entry
        }
    }

    private func cancelAfterGrace(key: String, imageKey: String, entryID: UUID) {
        guard let entry = entries[key],
              entry.id == entryID,
              entry.waiterCount == 0 else {
            return
        }
        entry.task.cancel()
        entries.removeValue(forKey: key)
        Logger.network.info(
            "image request cancellation grace expired imageKey=\(imageKey, privacy: .public) graceMs=\(Self.cancellationGraceMilliseconds)"
        )
    }

    private static func taskPriority(for priority: Float) -> TaskPriority {
        if priority <= ImageRequestPriority.background {
            return .background
        }
        if priority >= ImageRequestPriority.visible {
            return .userInitiated
        }
        return .utility
    }
}

final class DirectImageDataProvider: ImageDataProvider {
    let url: URL
    let cacheKey: String
    let priority: Float
    let usesSegmentedDownload: Bool

    init(
        url: URL,
        cacheKey: String? = nil,
        priority: Float = URLSessionTask.defaultPriority,
        usesSegmentedDownload: Bool = false
    ) {
        self.url = url
        self.cacheKey = cacheKey ?? url.absoluteString
        self.priority = priority
        self.usesSegmentedDownload = usesSegmentedDownload
    }

    var contentURL: URL? {
        url
    }

    func data() async throws -> Data {
        let url = self.url
        let cacheKey = self.cacheKey
        let headers = Self.requestHeaders(for: url)
        let priority = self.priority
        let usesSegmentedDownload = self.usesSegmentedDownload
        let imageKey = PixivImageRequestLogContext.key(for: url)
        let requestRole = PixivImageRequestLogContext.role(for: priority)
        let allowsCancellationGrace = usesSegmentedDownload && requestRole == "prefetch"

        return try await PixivImageRequestCoordinator.shared.data(
            for: cacheKey,
            imageKey: imageKey,
            priority: priority,
            allowsCancellationGrace: allowsCancellationGrace
        ) { priorityState in
            try await Self.downloadImageData(
                from: url,
                headers: headers,
                priorityState: priorityState,
                usesSegmentedDownload: usesSegmentedDownload
            )
        }
    }

    private static func requestHeaders(for url: URL) -> [String: String] {
        let request = URLRequest(url: url)
        return PixivImageLoader.shared.modified(for: request)?.allHTTPHeaderFields ?? [:]
    }

    private static func downloadImageData(
        from url: URL,
        headers: [String: String],
        priorityState: PixivImageRequestPriorityState,
        usesSegmentedDownload: Bool
    ) async throws -> Data {
        let requestID = String(UUID().uuidString.prefix(8))
        guard let host = url.host else {
            throw KingfisherError.imageSettingError(reason: .emptySource)
        }

        guard PixivNetworkConfiguration.isPixivImageHost(host) else {
            throw KingfisherError.imageSettingError(reason: .emptySource)
        }

        let priority = await priorityState.currentPriority()
        try Task.checkCancellation()
        let requestKind = PixivImageRequestLogContext.kind(for: url)
        let requestRole = PixivImageRequestLogContext.role(for: priority)
        let imageKey = PixivImageRequestLogContext.key(for: url)
        let domain = PixivImageDomain.selected.rawValue
        let routedHost = PixivNetworkConfiguration.routedImageURL(from: url).host ?? host
        let configuredConcurrency: Int?
        if usesSegmentedDownload {
            configuredConcurrency = await MainActor.run {
                UserSettingStore.shared.userSetting.downloadConcurrency
            }
        } else {
            configuredConcurrency = nil
        }
        let queuedAt = DispatchTime.now().uptimeNanoseconds
        let cancellationGraceMilliseconds = usesSegmentedDownload && requestRole == "prefetch"
            ? PixivImageRequestCoordinator.cancellationGraceMilliseconds
            : 0
        Logger.network.debug(
            "image request queued id=\(requestID, privacy: .public) imageKey=\(imageKey, privacy: .public) kind=\(requestKind, privacy: .public) role=\(requestRole, privacy: .public) domain=\(domain, privacy: .public) host=\(host, privacy: .public) routedHost=\(routedHost, privacy: .public) segmented=\(usesSegmentedDownload) configuredConcurrency=\(configuredConcurrency.map(String.init) ?? "1") priority=\(priority) cancellationGraceMs=\(cancellationGraceMilliseconds)"
        )

        let data: Data
        var activeAfter: Int?
        var networkStartedAt = queuedAt
        let tracksVisibleActivity = requestRole == "visible"
        if tracksVisibleActivity {
            await PixivVisibleImageActivity.shared.begin()
        } else if requestRole == "background" || requestRole == "prefetch" {
            await PixivVisibleImageActivity.shared.waitUntilIdle()
        }

        if usesSegmentedDownload {
            do {
                data = try await NetworkClient.shared.concurrentDownloadData(
                    from: url,
                    headers: headers,
                    concurrency: configuredConcurrency ?? 1,
                    priorityState: priorityState
                )
                if tracksVisibleActivity {
                    await PixivVisibleImageActivity.shared.end()
                }
            } catch {
                if tracksVisibleActivity {
                    await PixivVisibleImageActivity.shared.end()
                }
                let durationMs = (DispatchTime.now().uptimeNanoseconds - queuedAt) / 1_000_000
                let outcome = PixivImageRequestLogContext.isCancellation(error) ? "cancelled" : "failed"
                Logger.network.error(
                    "image request \(outcome, privacy: .public) id=\(requestID, privacy: .public) imageKey=\(imageKey, privacy: .public) kind=\(requestKind, privacy: .public) role=\(requestRole, privacy: .public) segmented=true durationMs=\(durationMs) error=\(error.localizedDescription, privacy: .public)"
                )
                throw error
            }
        } else {
            let activeCount = await PixivImageRequestLimiter.shared.acquireWithCount(priority: priority)
            networkStartedAt = DispatchTime.now().uptimeNanoseconds
            let queueWaitMs = (networkStartedAt - queuedAt) / 1_000_000
            let capacityClass = requestRole == "visible" ? "visible" : "shared"
            Logger.network.debug(
                "image request started id=\(requestID, privacy: .public) imageKey=\(imageKey, privacy: .public) kind=\(requestKind, privacy: .public) role=\(requestRole, privacy: .public) active=\(activeCount)/16 capacityClass=\(capacityClass, privacy: .public) visibleReserve=\(PixivImageRequestLimiter.visibleReservation) queueWaitMs=\(queueWaitMs)"
            )
            do {
                data = try await NetworkClient.shared.fetchImageData(from: url, headers: headers)
                activeAfter = await PixivImageRequestLimiter.shared.releaseWithCount()
                if tracksVisibleActivity {
                    await PixivVisibleImageActivity.shared.end()
                }
            } catch {
                activeAfter = await PixivImageRequestLimiter.shared.releaseWithCount()
                if tracksVisibleActivity {
                    await PixivVisibleImageActivity.shared.end()
                }
                let durationMs = (DispatchTime.now().uptimeNanoseconds - networkStartedAt) / 1_000_000
                let outcome = PixivImageRequestLogContext.isCancellation(error) ? "cancelled" : "failed"
                Logger.network.error(
                    "image request \(outcome, privacy: .public) id=\(requestID, privacy: .public) imageKey=\(imageKey, privacy: .public) kind=\(requestKind, privacy: .public) role=\(requestRole, privacy: .public) segmented=false durationMs=\(durationMs) activeAfter=\(activeAfter ?? 0) error=\(error.localizedDescription, privacy: .public)"
                )
                throw error
            }
        }

        let completedAt = DispatchTime.now().uptimeNanoseconds
        let totalDurationMs = (completedAt - queuedAt) / 1_000_000
        let networkDurationMs = (completedAt - networkStartedAt) / 1_000_000
        Logger.network.info(
            "image request completed id=\(requestID, privacy: .public) imageKey=\(imageKey, privacy: .public) kind=\(requestKind, privacy: .public) role=\(requestRole, privacy: .public) domain=\(domain, privacy: .public) segmented=\(usesSegmentedDownload) bytes=\(data.count) totalDurationMs=\(totalDurationMs) networkDurationMs=\(networkDurationMs) activeAfter=\(activeAfter.map(String.init) ?? "child")"
        )
        return data
    }

}

extension ImageDataProvider where Self == DirectImageDataProvider {
    static func direct(
        _ url: URL,
        cacheKey: String? = nil,
        priority: Float = URLSessionTask.defaultPriority,
        usesSegmentedDownload: Bool = false
    ) -> DirectImageDataProvider {
        DirectImageDataProvider(
            url: url,
            cacheKey: cacheKey,
            priority: priority,
            usesSegmentedDownload: usesSegmentedDownload
        )
    }
}

extension Source {
    nonisolated static func pixivNetwork(
        _ url: URL,
        cacheKey: String? = nil,
        priority: Float = URLSessionTask.defaultPriority
    ) -> Source {
        guard let host = url.host,
              PixivNetworkConfiguration.isPixivImageHost(host) else {
            return .network(KF.ImageResource(downloadURL: url, cacheKey: cacheKey))
        }
        let usesSegmentedDownload = PixivNetworkConfiguration.isOriginalImageURL(url)
        guard usesSegmentedDownload || PixivNetworkConfiguration.isDirectMode else {
            return .network(KF.ImageResource(downloadURL: url, cacheKey: cacheKey))
        }
        return .provider(
            DirectImageDataProvider(
                url: url,
                cacheKey: cacheKey,
                priority: priority,
                usesSegmentedDownload: usesSegmentedDownload
            )
        )
    }

    nonisolated static func directNetwork(
        _ url: URL,
        cacheKey: String? = nil,
        priority: Float = URLSessionTask.defaultPriority
    ) -> Source {
        .pixivNetwork(url, cacheKey: cacheKey, priority: priority)
    }
}

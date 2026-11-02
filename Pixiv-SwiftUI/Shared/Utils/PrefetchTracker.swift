import Foundation
import Kingfisher
import os.log

struct ImageRequestResult {
    let image: KFCrossPlatformImage
    let cacheType: String
}
@MainActor
final class ImageRequestCoordinator {
    static let shared = ImageRequestCoordinator()

    private struct Entry {
        let id: UUID
        let task: Task<ImageRequestResult, Error>
        var waiterIDs: Set<UUID>
        var progressCallbacks: [UUID: @MainActor @Sendable (Double?) -> Void]
        var latestProgress: Double?
        var hasReportedProgress: Bool
        var hasLoggedProgress: Bool
    }

    private var entries: [String: Entry] = [:]

    private init() {}

    func retrieve(
        key: String,
        operation: @escaping @Sendable (@escaping @Sendable (Double?) -> Void) async throws -> ImageRequestResult,
        onProgress: (@MainActor @Sendable (Double?) -> Void)? = nil
    ) async throws -> ImageRequestResult {
        let waiterID = UUID()
        let entry: Entry

        if var existingEntry = entries[key] {
            existingEntry.waiterIDs.insert(waiterID)
            if let onProgress {
                existingEntry.progressCallbacks[waiterID] = onProgress
            }
            entries[key] = existingEntry
            Logger.network.debug(
                "image progress waiter joined request=\(String(existingEntry.id.uuidString.prefix(8)), privacy: .public) waiters=\(existingEntry.waiterIDs.count) listeners=\(existingEntry.progressCallbacks.count) latest=\(existingEntry.hasReportedProgress)"
            )
            entry = existingEntry
            if existingEntry.hasReportedProgress {
                onProgress?(existingEntry.latestProgress)
            }
        } else {
            let requestID = UUID()
            let task = Task { [weak self] in
                try await operation { progress in
                    Task { @MainActor in
                        self?.reportProgress(key: key, requestID: requestID, progress: progress)
                    }
                }
            }
            let callbacks = onProgress.map { [waiterID: $0] } ?? [:]
            let newEntry = Entry(
                id: requestID,
                task: task,
                waiterIDs: [waiterID],
                progressCallbacks: callbacks,
                latestProgress: nil,
                hasReportedProgress: false,
                hasLoggedProgress: false
            )
            entries[key] = newEntry
            Logger.network.debug(
                "image progress request started request=\(String(requestID.uuidString.prefix(8)), privacy: .public) listeners=\(callbacks.count)"
            )
            entry = newEntry
        }

        return try await withTaskCancellationHandler(operation: {
            defer {
                release(key: key, requestID: entry.id, waiterID: waiterID)
            }
            return try await entry.task.value
        }, onCancel: {
            Task { @MainActor [weak self] in
                self?.release(key: key, requestID: entry.id, waiterID: waiterID)
            }
        })
    }

    private func reportProgress(key: String, requestID: UUID, progress: Double?) {
        guard var entry = entries[key], entry.id == requestID else { return }
        entry.latestProgress = progress
        entry.hasReportedProgress = true
        let shouldLog = !entry.hasLoggedProgress
        entry.hasLoggedProgress = true
        entries[key] = entry
        if shouldLog {
            let fraction = progress.map { String(format: "%.3f", $0) } ?? "unknown"
            Logger.network.debug(
                "image progress delivered request=\(String(requestID.uuidString.prefix(8)), privacy: .public) fraction=\(fraction, privacy: .public) listeners=\(entry.progressCallbacks.count) waiters=\(entry.waiterIDs.count)"
            )
        }
        for callback in entry.progressCallbacks.values {
            callback(progress)
        }
    }

    private func release(key: String, requestID: UUID, waiterID: UUID) {
        guard var entry = entries[key],
              entry.id == requestID,
              entry.waiterIDs.remove(waiterID) != nil
        else {
            return
        }

        entry.progressCallbacks.removeValue(forKey: waiterID)
        if entry.waiterIDs.isEmpty {
            entries.removeValue(forKey: key)
            entry.task.cancel()
        } else {
            entries[key] = entry
        }
    }
}
actor ImageCacheLookup {
    static let shared = ImageCacheLookup()

    func firstCachedURL(targetURL: String, fallbackURLs: [String]) -> String? {
        var seenURLs = Set<String>()

        for url in [targetURL] + fallbackURLs {
            guard !url.isEmpty,
                  let validURL = URL(string: url),
                  seenURLs.insert(url).inserted,
                  ImageCache.default.isCached(forKey: validURL.absoluteString) else {
                continue
            }
            return url
        }

        return nil
    }
}

enum ImageRequestKey {
    static func make(
        source: Kingfisher.Source,
        processorIdentifier: String?,
        targetCache: ImageCache?,
        expiration: TimeInterval
    ) -> String {
        let cacheIdentifier = targetCache.map { String(describing: ObjectIdentifier($0)) } ?? "default"
        return [
            source.cacheKey,
            processorIdentifier ?? "original",
            cacheIdentifier,
            String(expiration)
        ].joined(separator: "\u{1F}")
    }
}

enum ImageRequestPriority {
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

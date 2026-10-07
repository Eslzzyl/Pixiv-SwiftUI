import Foundation
import os.log

actor PixivImageRequestLimiter {
    static let shared = PixivImageRequestLimiter(limit: 16)
    static let visibleReservation = 4

    private struct Waiter {
        let waiterID: UUID
        let priority: Float
        let order: UInt64
        let continuation: CheckedContinuation<Bool, Never>
    }

    private let limit: Int
    private var activeCount = 0
    private var nextOrder: UInt64 = 0
    private var waiters: [Waiter] = []

    private init(limit: Int) {
        self.limit = limit
    }

    func acquire(priority: Float = URLSessionTask.defaultPriority) async -> Bool {
        await acquireWithCount(priority: priority) != nil
    }

    func acquireWithCount(priority: Float = URLSessionTask.defaultPriority) async -> Int? {
        guard !Task.isCancelled else { return nil }
        if canAcquire(priority: priority) {
            activeCount += 1
            return activeCount
        }

        let waiterID = UUID()
        let order = nextOrder
        nextOrder &+= 1
        let acquired = await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(returning: false)
                    return
                }
                waiters.append(
                    Waiter(
                        waiterID: waiterID,
                        priority: priority,
                        order: order,
                        continuation: continuation
                    )
                )
            }
        }, onCancel: {
            Task {
                await PixivImageRequestLimiter.shared.cancel(waiterID: waiterID)
            }
        })
        return acquired ? activeCount : nil
    }

    func release() {
        _ = releaseWithCount()
    }

    func releaseWithCount() -> Int {
        guard let waiterIndex = nextWaiterIndex() else {
            activeCount = max(0, activeCount - 1)
            return activeCount
        }

        let waiter = waiters.remove(at: waiterIndex)
        waiter.continuation.resume(returning: true)
        return activeCount
    }

    private func canAcquire(priority: Float) -> Bool {
        guard activeCount < limit else { return false }
        if priority >= ImageRequestPriority.visible {
            return true
        }
        return activeCount < limit - Self.visibleReservation
    }

    private func nextWaiterIndex() -> Int? {
        var bestIndex: Int?
        for index in waiters.indices where canAcquire(priority: waiters[index].priority) {
            guard let currentBestIndex = bestIndex else {
                bestIndex = index
                continue
            }
            let best = waiters[currentBestIndex]
            let candidate = waiters[index]
            if candidate.priority > best.priority
                || (candidate.priority == best.priority && candidate.order < best.order) {
                bestIndex = index
            }
        }
        return bestIndex
    }
    private func cancel(waiterID: UUID) {
        guard let waiterIndex = waiters.firstIndex(where: { $0.waiterID == waiterID }) else { return }
        let waiter = waiters.remove(at: waiterIndex)
        waiter.continuation.resume(returning: false)
    }

}

private actor PixivSegmentedDownloadLimiter {
    static let shared = PixivSegmentedDownloadLimiter()

    private struct RequestState {
        var priority: Float
        let requestedWorkers: Int
        var activeWorkers: Int
    }

    private struct Waiter {
        let waiterID: UUID
        let requestID: UUID
        var priority: Float
        let order: UInt64
        let continuation: CheckedContinuation<Bool, Never>
    }

    private let capacity = 16
    private var nextOrder: UInt64 = 0
    private var requests: [UUID: RequestState] = [:]
    private var waiters: [Waiter] = []

    func register(requestID: UUID, priority: Float, requestedWorkers: Int) -> Int {
        let state = RequestState(
            priority: priority,
            requestedWorkers: max(requestedWorkers, 1),
            activeWorkers: 0
        )
        requests[requestID] = state
        resumeWaiters()
        return workerLimit(for: state, visibleRequestCount: visibleRequestCount)
    }
    func promote(
        requestID: UUID,
        priority: Float
    ) -> (didPromote: Bool, activeWorkers: Int, workerLimit: Int) {
        guard var state = requests[requestID] else {
            return (false, 0, 0)
        }
        guard priority > state.priority else {
            return (
                false,
                state.activeWorkers,
                workerLimit(for: state, visibleRequestCount: visibleRequestCount)
            )
        }

        state.priority = priority
        requests[requestID] = state
        for index in waiters.indices where waiters[index].requestID == requestID {
            waiters[index].priority = priority
        }
        resumeWaiters()

        guard let updatedState = requests[requestID] else {
            return (true, 0, 0)
        }
        return (
            true,
            updatedState.activeWorkers,
            workerLimit(for: updatedState, visibleRequestCount: visibleRequestCount)
        )
    }

    func acquire(requestID: UUID) async -> Bool {
        guard !Task.isCancelled, requests[requestID] != nil else { return false }
        if canGrant(requestID: requestID) {
            grant(requestID: requestID)
            return true
        }

        let waiterID = UUID()
        let order = nextOrder
        nextOrder &+= 1
        return await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled, requests[requestID] != nil else {
                    continuation.resume(returning: false)
                    return
                }
                waiters.append(
                    Waiter(
                        waiterID: waiterID,
                        requestID: requestID,
                        priority: requests[requestID]?.priority ?? 0,
                        order: order,
                        continuation: continuation
                    )
                )
            }
        }, onCancel: {
            Task {
                await PixivSegmentedDownloadLimiter.shared.cancel(waiterID: waiterID)
            }
        })
    }

    func release(requestID: UUID) {
        if var state = requests[requestID] {
            state.activeWorkers = max(0, state.activeWorkers - 1)
            requests[requestID] = state
        }
        resumeWaiters()
    }

    func unregister(requestID: UUID) {
        requests.removeValue(forKey: requestID)
        let cancelledWaiters = waiters.filter { $0.requestID == requestID }
        waiters.removeAll { $0.requestID == requestID }
        cancelledWaiters.forEach { $0.continuation.resume(returning: false) }
        resumeWaiters()
    }

    private func cancel(waiterID: UUID) {
        guard let waiterIndex = waiters.firstIndex(where: { $0.waiterID == waiterID }) else { return }
        let waiter = waiters.remove(at: waiterIndex)
        waiter.continuation.resume(returning: false)
        resumeWaiters()
    }

    private func canGrant(requestID: UUID) -> Bool {
        guard let state = requests[requestID],
              activeWorkerCount < capacity else {
            return false
        }

        let workerLimit = workerLimit(for: state, visibleRequestCount: visibleRequestCount)
        return state.activeWorkers < workerLimit
    }

    private func workerLimit(for state: RequestState, visibleRequestCount: Int) -> Int {
        if state.priority >= ImageRequestPriority.visible {
            return min(
                state.requestedWorkers,
                max(1, capacity / max(visibleRequestCount, 1))
            )
        }
        if state.priority >= ImageRequestPriority.prefetch {
            return visibleRequestCount == 0 ? min(state.requestedWorkers, 2) : 0
        }
        return visibleRequestCount == 0 ? 1 : 0
    }

    private var visibleRequestCount: Int {
        requests.values.filter {
            $0.priority >= ImageRequestPriority.visible
        }.count
    }

    private var activeWorkerCount: Int {
        requests.values.reduce(0) { $0 + $1.activeWorkers }
    }

    private func grant(requestID: UUID) {
        guard var state = requests[requestID] else { return }
        state.activeWorkers += 1
        requests[requestID] = state
    }

    private func resumeWaiters() {
        while let waiterIndex = nextEligibleWaiterIndex() {
            let waiter = waiters.remove(at: waiterIndex)
            grant(requestID: waiter.requestID)
            waiter.continuation.resume(returning: true)
        }
    }

    private func nextEligibleWaiterIndex() -> Int? {
        var bestIndex: Int?
        for index in waiters.indices where canGrant(requestID: waiters[index].requestID) {
            guard let currentBestIndex = bestIndex else {
                bestIndex = index
                continue
            }
            let best = waiters[currentBestIndex]
            let candidate = waiters[index]
            if candidate.priority > best.priority
                || (candidate.priority == best.priority && candidate.order < best.order) {
                bestIndex = index
            }
        }
        return bestIndex
    }
}

private struct PixivDownloadRangeValidator: Sendable {
    let headerName: String
    let value: String
}

private enum PixivSegmentedDownloadFailure: Error {
    case rangeResponseMismatch
}
private struct PixivSegmentedDownloadContext: Sendable {
    let url: URL
    let headers: [String: String]
    let totalLength: Int64
    let ranges: [(start: Int64, end: Int64)]
    let validator: PixivDownloadRangeValidator?
    let priority: Float
    let priorityState: PixivImageRequestPriorityState
    let segmentedRequestID: String
    let requestID: UUID
    let workerCount: Int
    let initialWorkerLimit: Int
    let allowsUnvalidatedRanges: Bool
}
extension NetworkClient {
    /// 分片并发获取图片数据，分片与最终结果全程保留在内存中。
    func concurrentDownloadData(
        from sourceURL: URL,
        headers: [String: String] = [:],
        concurrency: Int = 4,
        priorityState: PixivImageRequestPriorityState
    ) async throws -> Data {
        let url = PixivNetworkConfiguration.routedImageURL(from: sourceURL)
        let safeConcurrency = min(max(concurrency, 1), 16)
        let priority = await priorityState.currentPriority()

        let hasRangeHeader = containsHeader("Range", in: headers)
        let allowsUnvalidatedRanges = sourceURL.host.map(PixivNetworkConfiguration.isPixivImageHost) ?? false
        guard safeConcurrency > 1, !hasRangeHeader else {
            let reason = safeConcurrency <= 1 ? "singleWorker" : "rangeHeaderPresent"
            Logger.network.debug(
                "image segmented bypass reason=\(reason, privacy: .public) configuredConcurrency=\(safeConcurrency) hasRangeHeader=\(hasRangeHeader)"
            )
            return try await fetchImageDataWithGlobalLimiter(from: url, headers: headers, priority: priority)
        }
        let segmentedRequestID = String(UUID().uuidString.prefix(8))
        var firstRangeHeaders = headers
        setHeader("bytes=0-\(downloadRangeSize - 1)", named: "Range", in: &firstRangeHeaders)
        setHeader("identity", named: "Accept-Encoding", in: &firstRangeHeaders)

        let firstRangeResult: (Data, HTTPURLResponse)
        guard await PixivImageRequestLimiter.shared.acquire(priority: priority) else {
            throw CancellationError()
        }
        do {
            try Task.checkCancellation()
            firstRangeResult = try await fetchImageDataWithResponse(from: url, headers: firstRangeHeaders)
            await PixivImageRequestLimiter.shared.release()
        } catch NetworkError.httpError(let statusCode) where [400, 405, 416, 501].contains(statusCode) {
            await PixivImageRequestLimiter.shared.release()
            Logger.network.info(
                "image segmented fallback id=\(segmentedRequestID, privacy: .public) reason=firstRangeHTTP\(statusCode)"
            )
            return try await fetchImageDataWithGlobalLimiter(from: url, headers: headers, priority: priority)
        } catch {
            await PixivImageRequestLimiter.shared.release()
            try rethrowSegmentedFailure(error, id: segmentedRequestID, phase: "firstRange")
        }

        var firstData = firstRangeResult.0
        let firstResponse = firstRangeResult.1
        let initialRange = parseContentRange(firstResponse.value(forHTTPHeaderField: "Content-Range"))
        let validator = strongRangeValidator(from: firstResponse)
        let identityEncoded = isIdentityEncoded(firstResponse)
        let hasValidFirstRange: Bool
        if let initialRange {
            hasValidFirstRange = firstResponse.statusCode == 206
                && initialRange.start == 0
                && initialRange.end == min(downloadRangeSize - 1, initialRange.total - 1)
                && Int64(firstData.count) == initialRange.end + 1
        } else {
            hasValidFirstRange = false
        }
        let sizeEligible = (initialRange?.total ?? 0) > minimumParallelDownloadSize
        Logger.network.debug(
            "image segmented first-range id=\(segmentedRequestID, privacy: .public) status=\(firstResponse.statusCode) rangeValid=\(hasValidFirstRange) responseBytes=\(firstData.count) totalBytes=\(initialRange?.total ?? 0) sizeEligible=\(sizeEligible) strongETag=\(validator != nil) unvalidatedRanges=\(allowsUnvalidatedRanges) identityEncoded=\(identityEncoded)"
        )

        if firstResponse.statusCode == 200 {
            Logger.network.debug(
                "image segmented direct id=\(segmentedRequestID, privacy: .public) reason=rangeIgnored bytes=\(firstData.count)"
            )
            return firstData
        }

        guard hasValidFirstRange,
              let initialRange,
              identityEncoded else {
            let reason: String
            if !hasValidFirstRange {
                reason = "invalidFirstRange"
            } else {
                reason = "nonIdentityEncoding"
            }
            Logger.network.info(
                "image segmented failure id=\(segmentedRequestID, privacy: .public) kind=rangeMismatch phase=firstRange"
            )
            Logger.network.info(
                "image segmented fallback id=\(segmentedRequestID, privacy: .public) reason=\(reason, privacy: .public) totalBytes=\(initialRange?.total ?? 0)"
            )
            firstData.removeAll(keepingCapacity: false)
            return try await fetchImageDataWithGlobalLimiter(from: url, headers: headers, priority: priority)
        }

        if !sizeEligible {
            Logger.network.debug(
                "image segmented direct id=\(segmentedRequestID, privacy: .public) reason=belowMinimumSize bytes=\(firstData.count)"
            )
            return firstData
        }

        guard validator != nil || allowsUnvalidatedRanges else {
            Logger.network.info(
                "image segmented fallback id=\(segmentedRequestID, privacy: .public) reason=missingStrongETag totalBytes=\(initialRange.total)"
            )
            firstData.removeAll(keepingCapacity: false)
            return try await fetchImageDataWithGlobalLimiter(from: url, headers: headers, priority: priority)
        }

        let totalLength = initialRange.total
        let chunkCount = min(safeConcurrency * 2, Int((totalLength - 1) / downloadRangeSize + 1))
        let ranges = (0..<chunkCount).map { index -> (start: Int64, end: Int64) in
            let start = Int64(index) * downloadRangeSize
            let end = min(totalLength - 1, start + downloadRangeSize - 1)
            return (start, end)
        }
        let workerCount = min(safeConcurrency, chunkCount)
        let requestID = UUID()
        let initialWorkerLimit = await PixivSegmentedDownloadLimiter.shared.register(
            requestID: requestID,
            priority: priority,
            requestedWorkers: workerCount
        )
        let context = PixivSegmentedDownloadContext(
            url: url,
            headers: headers,
            totalLength: totalLength,
            ranges: ranges,
            validator: validator,
            priority: priority,
            priorityState: priorityState,
            segmentedRequestID: segmentedRequestID,
            requestID: requestID,
            workerCount: workerCount,
            initialWorkerLimit: initialWorkerLimit,
            allowsUnvalidatedRanges: allowsUnvalidatedRanges
        )
        do {
            let result = try await downloadRemainingSegments(context: context, firstData: firstData)
            await PixivSegmentedDownloadLimiter.shared.unregister(requestID: requestID)
            return result
        } catch PixivSegmentedDownloadFailure.rangeResponseMismatch {
            await PixivSegmentedDownloadLimiter.shared.unregister(requestID: requestID)
            Logger.network.info(
                "image segmented failure id=\(segmentedRequestID, privacy: .public) kind=rangeMismatch phase=chunk"
            )
            Logger.network.info(
                "image segmented fallback id=\(segmentedRequestID, privacy: .public) reason=rangeResponseMismatch"
            )
            Logger.network.info("内存分片响应校验失败，改用单路图片请求")
            return try await fetchImageDataWithGlobalLimiter(from: url, headers: headers, priority: priority)
        } catch {
            await PixivSegmentedDownloadLimiter.shared.unregister(requestID: requestID)
            try rethrowSegmentedFailure(error, id: segmentedRequestID, phase: "chunk")
        }
    }

    private func downloadRemainingSegments(
        context: PixivSegmentedDownloadContext,
        firstData: Data
    ) async throws -> Data {
        let url = context.url
        let headers = context.headers
        let totalLength = context.totalLength
        let ranges = context.ranges
        let validator = context.validator
        let priority = context.priority
        let priorityState = context.priorityState
        let segmentedRequestID = context.segmentedRequestID
        let requestID = context.requestID
        let workerCount = context.workerCount
        let initialWorkerLimit = context.initialWorkerLimit
        let allowsUnvalidatedRanges = context.allowsUnvalidatedRanges
        let promotionMonitor = Task { [priorityState] in
            guard priority < ImageRequestPriority.visible else { return }
            while !Task.isCancelled {
                let effectivePriority = await priorityState.currentPriority()
                let promotion = await PixivSegmentedDownloadLimiter.shared.promote(
                    requestID: requestID,
                    priority: effectivePriority
                )
                if promotion.didPromote {
                    let promotedRole = PixivImageRequestLogContext.role(for: effectivePriority)
                    Logger.network.info(
                        "image segmented promotion id=\(segmentedRequestID, privacy: .public) role=\(promotedRole, privacy: .public) activeWorkers=\(promotion.activeWorkers) workerLimit=\(promotion.workerLimit) requestedWorkers=\(workerCount)"
                    )
                    return
                }
                do {
                    try await Task.sleep(for: .milliseconds(50))
                } catch {
                    return
                }
            }
        }
        defer {
            promotionMonitor.cancel()
        }

        let requestRole = PixivImageRequestLogContext.role(for: priority)
        Logger.network.debug(
            "image segmented budget id=\(segmentedRequestID, privacy: .public) role=\(requestRole, privacy: .public) requestedWorkers=\(workerCount) initialWorkers=\(initialWorkerLimit) chunks=\(ranges.count) visibleReserve=\(PixivImageRequestLimiter.visibleReservation) strongETag=\(validator != nil) unvalidatedRanges=\(allowsUnvalidatedRanges)"
        )

        var result = Data(count: Int(totalLength))
        var firstRangeData = firstData
        Self.copyData(firstRangeData, into: &result, at: Int(ranges[0].start))
        firstRangeData.removeAll(keepingCapacity: false)

        try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            for rangeIndex in ranges.indices.dropFirst() {
                let range = ranges[rangeIndex]
                group.addTask {
                    let effectivePriority = await priorityState.currentPriority()
                    let promotion = await PixivSegmentedDownloadLimiter.shared.promote(
                        requestID: requestID,
                        priority: effectivePriority
                    )
                    if promotion.didPromote {
                        let promotedRole = PixivImageRequestLogContext.role(for: effectivePriority)
                        Logger.network.info(
                            "image segmented promotion id=\(segmentedRequestID, privacy: .public) role=\(promotedRole, privacy: .public) activeWorkers=\(promotion.activeWorkers) workerLimit=\(promotion.workerLimit) requestedWorkers=\(workerCount)"
                        )
                    }
                    guard await PixivSegmentedDownloadLimiter.shared.acquire(requestID: requestID) else {
                        throw CancellationError()
                    }
                    guard await PixivImageRequestLimiter.shared.acquire(priority: effectivePriority) else {
                        await PixivSegmentedDownloadLimiter.shared.release(requestID: requestID)
                        throw CancellationError()
                    }
                    do {
                        try Task.checkCancellation()

                        var rangeHeaders = headers
                        self.setHeader("bytes=\(range.start)-\(range.end)", named: "Range", in: &rangeHeaders)
                        if let validator {
                            self.setHeader(validator.value, named: "If-Range", in: &rangeHeaders)
                        }
                        self.setHeader("identity", named: "Accept-Encoding", in: &rangeHeaders)

                        let (data, response) = try await self.fetchImageDataWithResponse(
                            from: url,
                            headers: rangeHeaders
                        )
                        let validatorMatches = validator.map {
                            response.value(forHTTPHeaderField: $0.headerName) == $0.value
                        } ?? true
                        guard response.statusCode == 206,
                              self.isIdentityEncoded(response),
                              validatorMatches,
                              let receivedRange = self.parseContentRange(response.value(forHTTPHeaderField: "Content-Range")),
                              receivedRange.start == range.start,
                              receivedRange.end == range.end,
                              receivedRange.total == totalLength,
                              Int64(data.count) == range.end - range.start + 1 else {
                            throw PixivSegmentedDownloadFailure.rangeResponseMismatch
                        }
                        await PixivImageRequestLimiter.shared.release()
                        await PixivSegmentedDownloadLimiter.shared.release(requestID: requestID)
                        return (rangeIndex, data)
                    } catch {
                        await PixivImageRequestLimiter.shared.release()
                        await PixivSegmentedDownloadLimiter.shared.release(requestID: requestID)
                        throw error
                    }
                }
            }

            for try await (rangeIndex, data) in group {
                let range = ranges[rangeIndex]
                guard Int64(data.count) == range.end - range.start + 1 else {
                    throw PixivSegmentedDownloadFailure.rangeResponseMismatch
                }
                Self.copyData(data, into: &result, at: Int(range.start))
            }
        }

        try Task.checkCancellation()
        guard Int64(result.count) == totalLength else {
            throw PixivSegmentedDownloadFailure.rangeResponseMismatch
        }
        return result
    }

    private func rethrowSegmentedFailure(
        _ error: Error,
        id: String,
        phase: String
    ) throws -> Never {
        if PixivImageRequestLogContext.isCancellation(error) {
            Logger.network.info(
                "image segmented failure id=\(id, privacy: .public) kind=cancelled phase=\(phase, privacy: .public)"
            )
            throw CancellationError()
        }
        Logger.network.info(
            "image segmented failure id=\(id, privacy: .public) kind=transportFailure phase=\(phase, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
        )
        throw error
    }

    private func fetchImageDataWithGlobalLimiter(
        from url: URL,
        headers: [String: String],
        priority: Float
    ) async throws -> Data {
        guard await PixivImageRequestLimiter.shared.acquire(priority: priority) else {
            throw CancellationError()
        }
        do {
            try Task.checkCancellation()
            let data = try await fetchImageData(from: url, headers: headers)
            await PixivImageRequestLimiter.shared.release()
            return data
        } catch {
            await PixivImageRequestLimiter.shared.release()
            throw error
        }
    }

    /// 分片并发下载文件
    func concurrentDownload(
        from sourceURL: URL,
        headers: [String: String] = [:],
        destinationURL: URL? = nil,
        concurrency: Int = 4,
        onProgress: (@Sendable (Int64, Int64?) -> Void)? = nil
    ) async throws -> (URL, URLResponse) {
        let url = PixivNetworkConfiguration.routedImageURL(from: sourceURL)
        let fileManager = FileManager.default
        let tempURL: URL
        if let destinationURL {
            let directoryURL = destinationURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            tempURL = directoryURL.appendingPathComponent(".\(destinationURL.lastPathComponent).\(UUID().uuidString).download")
        } else {
            tempURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp")
        }
        let lastReportedBytes = OSAllocatedUnfairLock(initialState: Int64(0))
        let reportProgress: @Sendable (Int64, Int64?) -> Void = { received, total in
            let safeReceived = lastReportedBytes.withLock { last in
                let candidate = total.map { min(received, $0) } ?? received
                last = max(last, candidate)
                return last
            }
            onProgress?(safeReceived, total)
        }
        var completed = false
        defer {
            if !completed {
                try? fileManager.removeItem(at: tempURL)
            }
        }

        func finish(_ result: (URL, URLResponse)) throws -> (URL, URLResponse) {
            guard let destinationURL else {
                completed = true
                return result
            }

            if fileManager.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
                _ = try fileManager.replaceItemAt(destinationURL, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: destinationURL)
            }
            completed = true
            return (destinationURL, result.1)
        }

        if !fileManager.fileExists(atPath: tempURL.path(percentEncoded: false)) {
            fileManager.createFile(atPath: tempURL.path(percentEncoded: false), contents: nil)
        }
        let initialFileHandle = try FileHandle(forWritingTo: tempURL)
        try initialFileHandle.truncate(atOffset: 0)
        try initialFileHandle.close()

        let safeConcurrency = min(max(concurrency, 1), 16)
        if safeConcurrency == 1 || containsHeader("Range", in: headers) {
            let result = try await urlSessionDownloadWithByteProgress(
                from: url,
                headers: headers,
                destinationURL: tempURL,
                onProgress: reportProgress,
                maxRetryCount: maxDownloadRetryCount
            )
            return try finish(result)
        }

        var probeHeaders = headers
        setHeader("bytes=0-0", named: "Range", in: &probeHeaders)
        setHeader("identity", named: "Accept-Encoding", in: &probeHeaders)
        let probeResult: (URL, URLResponse)
        do {
            probeResult = try await urlSessionDownloadWithByteProgress(
                from: url,
                headers: probeHeaders,
                destinationURL: tempURL,
                maxRetryCount: maxDownloadRetryCount
            )
        } catch NetworkError.httpError(let statusCode) where [400, 405, 416, 501].contains(statusCode) {
            try? FileManager.default.removeItem(at: tempURL)
            let result = try await urlSessionDownloadWithByteProgress(
                from: url,
                headers: headers,
                destinationURL: tempURL,
                onProgress: reportProgress,
                maxRetryCount: maxDownloadRetryCount
            )
            return try finish(result)
        }
        guard let probeResponse = probeResult.1 as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if probeResponse.statusCode == 200 {
            let fileSize = ((try? FileManager.default.attributesOfItem(atPath: tempURL.path(percentEncoded: false))[.size]) as? NSNumber)?.int64Value ?? 0
            let totalSize = probeResponse.expectedContentLength > 0 ? probeResponse.expectedContentLength : fileSize
            reportProgress(fileSize, totalSize > 0 ? totalSize : nil)
            return try finish(probeResult)
        }

        guard probeResponse.statusCode == 206,
              let initialRange = parseContentRange(probeResponse.value(forHTTPHeaderField: "Content-Range")),
              initialRange.start == 0,
              initialRange.end == 0,
              initialRange.total > minimumParallelDownloadSize,
              let validator = strongRangeValidator(from: probeResponse),
              isIdentityEncoded(probeResponse) else {
            try? FileManager.default.removeItem(at: tempURL)
            let result = try await urlSessionDownloadWithByteProgress(
                from: url,
                headers: headers,
                destinationURL: tempURL,
                onProgress: reportProgress,
                maxRetryCount: maxDownloadRetryCount
            )
            return try finish(result)
        }

        let totalLength = initialRange.total
        let chunkCount = min(safeConcurrency * 2, Int((totalLength - 1) / downloadRangeSize + 1))
        guard chunkCount > 1 else {
            try? FileManager.default.removeItem(at: tempURL)
            let result = try await urlSessionDownloadWithByteProgress(
                from: url,
                headers: headers,
                destinationURL: tempURL,
                onProgress: reportProgress,
                maxRetryCount: maxDownloadRetryCount
            )
            return try finish(result)
        }

        let ranges = (0..<chunkCount).map { index -> (start: Int64, end: Int64) in
            let start = Int64(index) * totalLength / Int64(chunkCount)
            let end = Int64(index + 1) * totalLength / Int64(chunkCount) - 1
            return (start, end)
        }
        let outputHandle = try FileHandle(forWritingTo: tempURL)
        try outputHandle.truncate(atOffset: UInt64(totalLength))
        try outputHandle.close()

        let workerCount = min(safeConcurrency, chunkCount)
        let retryLimit = maxDownloadRetryCount

        do {
            try await downloadFileRanges(
                from: url,
                headers: headers,
                destinationURL: tempURL,
                totalLength: totalLength,
                ranges: ranges,
                workerCount: workerCount,
                validator: validator,
                retryLimit: retryLimit,
                reportProgress: reportProgress
            )
        } catch NetworkError.rangeNotSupported {
            Logger.network.info("服务器分段响应与探测结果不一致，改用单路下载")
            try? FileManager.default.removeItem(at: tempURL)
            let result = try await urlSessionDownloadWithByteProgress(
                from: url,
                headers: headers,
                destinationURL: tempURL,
                onProgress: reportProgress,
                maxRetryCount: maxDownloadRetryCount
            )
            return try finish(result)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }

        return try finish((tempURL, probeResponse))
    }
    private func downloadFileRanges(
        from url: URL,
        headers: [String: String],
        destinationURL: URL,
        totalLength: Int64,
        ranges: [(start: Int64, end: Int64)],
        workerCount: Int,
        validator: PixivDownloadRangeValidator,
        retryLimit: Int,
        reportProgress: @escaping @Sendable (Int64, Int64?) -> Void
    ) async throws {
        let nextRangeIndex = OSAllocatedUnfairLock(initialState: 0)
        let receivedBytes = OSAllocatedUnfairLock(initialState: Int64(0))

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<workerCount {
                group.addTask {
                    while true {
                        let rangeIndex: Int? = nextRangeIndex.withLock { index -> Int? in
                            guard index < ranges.count else { return nil }
                            defer { index += 1 }
                            return index
                        }
                        guard let rangeIndex else { return }
                        try Task.checkCancellation()
                        try await self.downloadFileRange(
                            from: url,
                            headers: headers,
                            destinationURL: destinationURL,
                            totalLength: totalLength,
                            range: ranges[rangeIndex],
                            validator: validator,
                            retryLimit: retryLimit,
                            receivedBytes: receivedBytes,
                            reportProgress: reportProgress
                        )
                    }
                }
            }
            try await group.waitForAll()
        }

        try Task.checkCancellation()
        let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path(percentEncoded: false))
        guard let actualSize = attributes[.size] as? Int64, actualSize == totalLength else {
            throw NetworkError.rangeNotSupported
        }
        reportProgress(totalLength, totalLength)
    }

    private func downloadFileRange(
        from url: URL,
        headers: [String: String],
        destinationURL: URL,
        totalLength: Int64,
        range: (start: Int64, end: Int64),
        validator: PixivDownloadRangeValidator,
        retryLimit: Int,
        receivedBytes: OSAllocatedUnfairLock<Int64>,
        reportProgress: @escaping @Sendable (Int64, Int64?) -> Void
    ) async throws {
        var rangeHeaders = headers
        setHeader("bytes=\(range.start)-\(range.end)", named: "Range", in: &rangeHeaders)
        setHeader(validator.value, named: "If-Range", in: &rangeHeaders)
        setHeader("identity", named: "Accept-Encoding", in: &rangeHeaders)

        let chunkURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".part")
        defer { try? FileManager.default.removeItem(at: chunkURL) }
        let chunkReceived = OSAllocatedUnfairLock(initialState: Int64(0))

        guard await PixivImageRequestLimiter.shared.acquire() else {
            throw CancellationError()
        }
        let response: URLResponse
        do {
            try Task.checkCancellation()
            let result = try await urlSessionDownloadWithByteProgress(
                from: url,
                headers: rangeHeaders,
                destinationURL: chunkURL,
                onProgress: { receivedInChunk, _ in
                    let delta = chunkReceived.withLock { previous -> Int64 in
                        let delta = max(0, receivedInChunk - previous)
                        previous = max(previous, receivedInChunk)
                        return delta
                    }
                    let total = receivedBytes.withLock { current -> Int64 in
                        current = min(totalLength, current + delta)
                        return current
                    }
                    reportProgress(total, totalLength)
                },
                maxRetryCount: retryLimit
            )
            response = result.1
            await PixivImageRequestLimiter.shared.release()
        } catch NetworkError.httpError(let statusCode) where [400, 416, 501].contains(statusCode) {
            await PixivImageRequestLimiter.shared.release()
            throw NetworkError.rangeNotSupported
        } catch {
            await PixivImageRequestLimiter.shared.release()
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 206,
              isIdentityEncoded(httpResponse),
              httpResponse.value(forHTTPHeaderField: validator.headerName) == validator.value,
              let receivedRange = parseContentRange(httpResponse.value(forHTTPHeaderField: "Content-Range")),
              receivedRange.start >= range.start,
              receivedRange.end == range.end,
              receivedRange.total == totalLength else {
            throw NetworkError.rangeNotSupported
        }

        let expectedChunkLength = range.end - range.start + 1
        let attributes = try FileManager.default.attributesOfItem(atPath: chunkURL.path(percentEncoded: false))
        guard let chunkLength = attributes[.size] as? Int64,
              chunkLength == expectedChunkLength else {
            throw NetworkError.rangeNotSupported
        }

        try Self.copyFile(from: chunkURL, to: destinationURL, offset: UInt64(range.start))
    }

    nonisolated private static func copyData(_ source: Data, into destination: inout Data, at offset: Int) {
        guard !source.isEmpty else { return }
        destination.withUnsafeMutableBytes { destinationBuffer in
            source.withUnsafeBytes { sourceBuffer in
                guard let destinationBase = destinationBuffer.baseAddress,
                      let sourceBase = sourceBuffer.baseAddress else {
                    return
                }
                destinationBase.advanced(by: offset).copyMemory(
                    from: sourceBase,
                    byteCount: sourceBuffer.count
                )
            }
        }
    }

    nonisolated private func containsHeader(_ name: String, in headers: [String: String]) -> Bool {
        headers.keys.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    nonisolated private func setHeader(_ value: String, named name: String, in headers: inout [String: String]) {
        for key in Array(headers.keys) where key.caseInsensitiveCompare(name) == .orderedSame {
            headers.removeValue(forKey: key)
        }
        headers[name] = value
    }

    nonisolated private func strongRangeValidator(from response: HTTPURLResponse) -> PixivDownloadRangeValidator? {
        guard let etag = response.value(forHTTPHeaderField: "ETag")?.trimmingCharacters(in: .whitespacesAndNewlines),
              etag.count >= 2,
              etag.first == "\"",
              etag.last == "\"",
              !etag.dropFirst().dropLast().contains("\""),
              !etag.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            return nil
        }

        return PixivDownloadRangeValidator(headerName: "ETag", value: etag)
    }

    nonisolated private func isIdentityEncoded(_ response: HTTPURLResponse) -> Bool {
        guard let encoding = response.value(forHTTPHeaderField: "Content-Encoding") else { return true }
        return encoding.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("identity") == .orderedSame
    }

    nonisolated private static func copyFile(from sourceURL: URL, to destinationURL: URL, offset: UInt64) throws {
        let source = try FileHandle(forReadingFrom: sourceURL)
        let destination = try FileHandle(forWritingTo: destinationURL)
        defer {
            try? source.close()
            try? destination.close()
        }

        try destination.seek(toOffset: offset)
        while let data = try source.read(upToCount: 64 * 1024), !data.isEmpty {
            try Task.checkCancellation()
            try destination.write(contentsOf: data)
        }
    }

}

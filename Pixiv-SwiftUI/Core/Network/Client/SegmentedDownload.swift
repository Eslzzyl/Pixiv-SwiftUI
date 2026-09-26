import Foundation
import os.log

private actor PixivDownloadConcurrencyLimiter {
    static let shared = PixivDownloadConcurrencyLimiter(limit: 16)

    private let limit: Int
    private var activeCount = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private init(limit: Int) {
        self.limit = limit
    }

    func acquire() async {
        if activeCount < limit {
            activeCount += 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            activeCount = max(0, activeCount - 1)
        } else {
            waiters.removeFirst().resume()
        }
    }
}

private struct PixivDownloadRangeValidator: Sendable {
    let headerName: String
    let value: String
}

extension NetworkClient {
    /// 分片并发下载文件
    func concurrentDownload(
        from url: URL,
        headers: [String: String] = [:],
        destinationURL: URL? = nil,
        concurrency: Int = 4,
        onProgress: (@Sendable (Int64, Int64?) -> Void)? = nil
    ) async throws -> (URL, URLResponse) {
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

        let nextRangeIndex = OSAllocatedUnfairLock(initialState: 0)
        let receivedBytes = OSAllocatedUnfairLock(initialState: Int64(0))
        let workerCount = min(safeConcurrency, chunkCount)
        let retryLimit = maxDownloadRetryCount

        do {
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

                            let range = ranges[rangeIndex]
                            var rangeHeaders = headers
                            self.setHeader("bytes=\(range.start)-\(range.end)", named: "Range", in: &rangeHeaders)
                            self.setHeader(validator.value, named: "If-Range", in: &rangeHeaders)
                            self.setHeader("identity", named: "Accept-Encoding", in: &rangeHeaders)

                            let chunkURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString + ".part")
                            defer { try? FileManager.default.removeItem(at: chunkURL) }

                            let chunkReceived = OSAllocatedUnfairLock(initialState: Int64(0))
                            await PixivDownloadConcurrencyLimiter.shared.acquire()
                            let response: URLResponse
                            do {
                                try Task.checkCancellation()
                                let result = try await self.urlSessionDownloadWithByteProgress(
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
                                await PixivDownloadConcurrencyLimiter.shared.release()
                            } catch NetworkError.httpError(let statusCode) where [400, 416, 501].contains(statusCode) {
                                await PixivDownloadConcurrencyLimiter.shared.release()
                                throw NetworkError.rangeNotSupported
                            } catch {
                                await PixivDownloadConcurrencyLimiter.shared.release()
                                throw error
                            }

                            guard let httpResponse = response as? HTTPURLResponse,
                                  httpResponse.statusCode == 206,
                                  self.isIdentityEncoded(httpResponse),
                                  httpResponse.value(forHTTPHeaderField: validator.headerName) == validator.value,
                                  let receivedRange = self.parseContentRange(httpResponse.value(forHTTPHeaderField: "Content-Range")),
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

                            try Self.copyFile(from: chunkURL, to: tempURL, offset: UInt64(range.start))
                        }
                    }
                }
                try await group.waitForAll()
            }

            try Task.checkCancellation()
            let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path(percentEncoded: false))
            guard let actualSize = attributes[.size] as? Int64, actualSize == totalLength else {
                throw NetworkError.rangeNotSupported
            }
            reportProgress(totalLength, totalLength)
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

import Foundation

nonisolated final class PixivDownloadFileWriter: @unchecked Sendable {
    private let destinationURL: URL
    private let onProgress: (@Sendable (Int64, Int64?) -> Void)?
    private let lock = NSLock()
    private var fileHandle: FileHandle?
    private var receivedBytes: Int64 = 0
    private var totalBytes: Int64?

    init(destinationURL: URL, onProgress: (@Sendable (Int64, Int64?) -> Void)?) {
        self.destinationURL = destinationURL
        self.onProgress = onProgress
    }

    func begin(append: Bool, receivedBytes: Int64, totalBytes: Int64?) throws {
        lock.lock()
        defer { lock.unlock() }
        try fileHandle?.close()
        fileHandle = nil
        if !FileManager.default.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
            FileManager.default.createFile(atPath: destinationURL.path(percentEncoded: false), contents: nil)
        }
        let handle = try FileHandle(forWritingTo: destinationURL)
        if append {
            try handle.seekToEnd()
        } else {
            try handle.truncate(atOffset: 0)
        }
        self.fileHandle = handle
        self.receivedBytes = receivedBytes
        self.totalBytes = totalBytes
    }

    func append(_ data: Data) throws {
        lock.lock()
        guard let fileHandle else {
            lock.unlock()
            throw PixivDirectConnectionError.invalidResponse
        }
        do {
            try fileHandle.write(contentsOf: data)
            receivedBytes += Int64(data.count)
            let progress = receivedBytes
            let total = totalBytes
            lock.unlock()
            onProgress?(progress, total)
        } catch {
            lock.unlock()
            throw error
        }
    }

    func close() throws {
        lock.lock()
        let handle = fileHandle
        fileHandle = nil
        lock.unlock()
        try handle?.close()
    }
}

nonisolated final class PixivDownloadRetryState: @unchecked Sendable {
    private let lock = NSLock()
    private var validator: String?

    func update(from response: HTTPURLResponse) {
        let strongValidator = pixivStrongEntityTag(response.value(forHTTPHeaderField: "ETag"))
        lock.lock()
        validator = strongValidator
        lock.unlock()
    }

    func reset() {
        lock.lock()
        validator = nil
        lock.unlock()
    }

    var strongValidator: String? {
        lock.lock()
        defer { lock.unlock() }
        return validator
    }
}

nonisolated func pixivStrongEntityTag(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          value.hasPrefix("\""),
          value.hasSuffix("\""),
          !value.lowercased().hasPrefix("w/") else {
        return nil
    }
    return value
}

nonisolated func pixivContentRange(_ value: String?) -> (start: Int64, end: Int64, total: Int64)? {
    guard let value else { return nil }
    let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ", maxSplits: 1)
    guard parts.count == 2,
          parts[0].caseInsensitiveCompare("bytes") == .orderedSame else {
        return nil
    }
    let rangeAndTotal = parts[1].split(separator: "/", maxSplits: 1)
    guard rangeAndTotal.count == 2,
          let total = Int64(rangeAndTotal[1]),
          total > 0 else {
        return nil
    }
    let range = rangeAndTotal[0].split(separator: "-", maxSplits: 1)
    guard range.count == 2,
          let start = Int64(range[0]),
          let end = Int64(range[1]),
          start >= 0,
          end >= start,
          end < total else {
        return nil
    }
    return (start, end, total)
}

nonisolated func pixivResponseUsesIdentityEncoding(_ response: HTTPURLResponse) -> Bool {
    guard let encoding = response.value(forHTTPHeaderField: "Content-Encoding") else { return true }
    return encoding.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("identity") == .orderedSame
}

nonisolated func pixivRetryAfterMilliseconds(_ response: HTTPURLResponse) -> Int? {
    guard let retryAfter = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespacesAndNewlines),
          !retryAfter.isEmpty else {
        return nil
    }
    if let seconds = Double(retryAfter), seconds.isFinite {
        return Int(min(max(seconds, 0), 10) * 1_000)
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
    guard let retryDate = formatter.date(from: retryAfter) else { return nil }
    return Int(min(max(retryDate.timeIntervalSinceNow, 0), 10) * 1_000)
}

nonisolated func pixivContainsHeader(_ name: String, in headers: [String: String]) -> Bool {
    headers.keys.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
}

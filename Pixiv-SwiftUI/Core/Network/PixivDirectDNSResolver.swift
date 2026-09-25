import Foundation
import os.log

nonisolated private struct PixivDirectDNSResolution: Sendable {
    let addresses: [String]
    let ttl: TimeInterval
}

private struct PixivDirectDNSCacheEntry {
    let addresses: [String]
    let expiresAt: Date
    let staleUntil: Date
    var retryAfter: Date
    var lastAccessedAt: Date
}

private struct PixivDirectDNSLookup {
    let id: UUID
    let task: Task<PixivDirectDNSResolution?, Never>
}

actor PixivDirectDNSResolver {
    static let shared = PixivDirectDNSResolver()

    private let session: URLSession
    private let maximumCachedLifetime: TimeInterval = 300
    private let staleGracePeriod: TimeInterval = 300
    private let failedLookupCooldown: TimeInterval = 30
    private let lookupTimeout: TimeInterval = 3
    private let maximumCachedHosts = 16
    private let maximumAddressesPerHost = 4
    private var cache: [String: PixivDirectDNSCacheEntry] = [:]
    private var inFlightLookups: [String: PixivDirectDNSLookup] = [:]

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = lookupTimeout
        configuration.timeoutIntervalForResource = lookupTimeout + 1
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable as String: 0,
            kCFNetworkProxiesHTTPSEnable as String: 0,
        ]
        session = URLSession(configuration: configuration)
    }

    func addresses(
        for host: String,
        fallbackAddresses: [String],
        deadline: PixivRequestDeadline
    ) async -> [String] {
        let normalizedHost = host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        let fallback = unique(fallbackAddresses)
        guard !normalizedHost.isEmpty else { return fallback }

        let now = Date()
        if var entry = cache[normalizedHost] {
            entry.lastAccessedAt = now
            cache[normalizedHost] = entry
            if entry.expiresAt > now {
                return unique(fallback + entry.addresses)
            }
            let staleAddresses = entry.staleUntil > now ? entry.addresses : []
            if entry.retryAfter > now {
                return unique(fallback + staleAddresses)
            }
        }

        let remainingTime = deadline.remainingTimeInterval
        guard remainingTime > 0.1 else {
            return addressesFromStaleCache(for: normalizedHost, fallback: fallback)
        }

        let lookup: PixivDirectDNSLookup
        if let existingLookup = inFlightLookups[normalizedHost] {
            lookup = existingLookup
        } else {
            let id = UUID()
            let timeout = min(lookupTimeout, remainingTime)
            let maximumAddresses = maximumAddressesPerHost
            let session = self.session
            let task = Task {
                await Self.performLookup(
                    host: normalizedHost,
                    timeout: timeout,
                    maximumAddresses: maximumAddresses,
                    session: session
                )
            }
            lookup = PixivDirectDNSLookup(id: id, task: task)
            inFlightLookups[normalizedHost] = lookup
        }

        let resolution = await lookup.task.value
        if inFlightLookups[normalizedHost]?.id == lookup.id {
            inFlightLookups.removeValue(forKey: normalizedHost)
        }

        if let resolution, !resolution.addresses.isEmpty {
            if resolution.ttl > 0 {
                let cachedLifetime = min(resolution.ttl, maximumCachedLifetime)
                let expiresAt = Date().addingTimeInterval(cachedLifetime)
                store(
                    PixivDirectDNSCacheEntry(
                        addresses: resolution.addresses,
                        expiresAt: expiresAt,
                        staleUntil: expiresAt.addingTimeInterval(staleGracePeriod),
                        retryAfter: expiresAt,
                        lastAccessedAt: Date()
                    ),
                    for: normalizedHost
                )
            }
            Logger.network.info(
                "HTTP/3 DoH lookup accepted host=\(normalizedHost, privacy: .public) addresses=\(resolution.addresses.count) ttl=\(resolution.ttl)"
            )
            return unique(fallback + resolution.addresses)
        }

        let failureTime = Date()
        if var entry = cache[normalizedHost] {
            entry.retryAfter = failureTime.addingTimeInterval(failedLookupCooldown)
            entry.lastAccessedAt = failureTime
            cache[normalizedHost] = entry
        } else {
            store(
                PixivDirectDNSCacheEntry(
                    addresses: [],
                    expiresAt: failureTime,
                    staleUntil: failureTime,
                    retryAfter: failureTime.addingTimeInterval(failedLookupCooldown),
                    lastAccessedAt: failureTime
                ),
                for: normalizedHost
            )
        }
        return addressesFromStaleCache(for: normalizedHost, fallback: fallback)
    }

    private func addressesFromStaleCache(for host: String, fallback: [String]) -> [String] {
        guard let entry = cache[host], entry.staleUntil > Date() else {
            return fallback
        }
        return unique(fallback + entry.addresses)
    }

    private func store(_ entry: PixivDirectDNSCacheEntry, for host: String) {
        cache[host] = entry
        guard cache.count > maximumCachedHosts,
              let leastRecentlyUsedHost = cache.min(by: {
                  $0.value.lastAccessedAt < $1.value.lastAccessedAt
              })?.key else {
            return
        }
        cache.removeValue(forKey: leastRecentlyUsedHost)
    }

    private func unique(_ addresses: [String]) -> [String] {
        var seen = Set<String>()
        return addresses.filter { seen.insert($0).inserted }
    }

    private nonisolated static func performLookup(
        host: String,
        timeout: TimeInterval,
        maximumAddresses: Int,
        session: URLSession
    ) async -> PixivDirectDNSResolution? {
        guard let query = PixivDirectDNSMessage.makeQuery(for: host),
              let endpoint = URL(string: "https://doh.360.cn/dns-query") else {
            return nil
        }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "dns", value: query.message.base64URLEncodedString),
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/dns-message", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?
                    .split(separator: ";", maxSplits: 1)
                    .first?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased(),
                  contentType == "application/dns-message" else {
                return nil
            }
            let resolution = PixivDirectDNSMessage.parseResponse(
                data,
                for: host,
                queryID: query.id,
                maximumAddresses: maximumAddresses
            )
            if resolution == nil {
                Logger.network.notice(
                    "HTTP/3 DoH response rejected host=\(host, privacy: .public) reason=no usable IPv4 answer"
                )
            }
            return resolution
        } catch {
            Logger.network.debug(
                "HTTP/3 DoH lookup failed host=\(host, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}

nonisolated private enum PixivDirectDNSMessage {
    private struct AliasRecord {
        let target: String
        let ttl: UInt32
    }

    private struct AddressRecord {
        let owner: String
        let address: String
        let ttl: UInt32
    }

    static func makeQuery(for host: String) -> (id: UInt16, message: Data)? {
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return nil }

        let id = UInt16.random(in: UInt16.min...UInt16.max)
        var message = Data([UInt8(id >> 8), UInt8(id & 0xff)])
        message.append(contentsOf: [0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])

        for label in labels {
            let bytes = Data(label.utf8)
            guard !bytes.isEmpty, bytes.count <= 63 else { return nil }
            message.append(UInt8(bytes.count))
            message.append(bytes)
        }
        message.append(0)
        message.append(contentsOf: [0x00, 0x01, 0x00, 0x01])
        return (id, message)
    }

    static func parseResponse(
        _ data: Data,
        for host: String,
        queryID: UInt16,
        maximumAddresses: Int
    ) -> PixivDirectDNSResolution? {
        guard data.count >= 12,
              readUInt16(data, at: 0) == queryID,
              let flags = readUInt16(data, at: 2),
              let questionCount = readUInt16(data, at: 4),
              let answerCount = readUInt16(data, at: 6),
              flags & 0x8000 != 0,
              flags & 0x7800 == 0,
              flags & 0x0200 == 0,
              flags & 0x000F == 0,
              questionCount == 1,
              answerCount > 0,
              answerCount <= 64,
              let question = readName(data, at: 12),
              question.name == normalizedName(host),
              let questionType = readUInt16(data, at: question.nextOffset),
              let questionClass = readUInt16(data, at: question.nextOffset + 2),
              questionType == 1,
              questionClass == 1 else {
            return nil
        }

        var offset = question.nextOffset + 4
        var aliases: [String: AliasRecord] = [:]
        var addresses: [AddressRecord] = []

        for _ in 0..<answerCount {
            guard let owner = readName(data, at: offset) else { return nil }
            offset = owner.nextOffset
            guard let type = readUInt16(data, at: offset),
                  let recordClass = readUInt16(data, at: offset + 2),
                  let ttl = readUInt32(data, at: offset + 4),
                  let recordLength = readUInt16(data, at: offset + 8) else {
                return nil
            }
            let dataStart = offset + 10
            let dataEnd = dataStart + Int(recordLength)
            guard dataEnd <= data.count else { return nil }

            if recordClass == 1, type == 1, recordLength == 4 {
                let octets = data[dataStart..<dataEnd]
                let address = octets.map(String.init).joined(separator: ".")
                addresses.append(AddressRecord(owner: owner.name, address: address, ttl: ttl))
            } else if recordClass == 1, type == 5,
                      let target = readName(data, at: dataStart), target.nextOffset <= dataEnd {
                aliases[owner.name] = AliasRecord(target: target.name, ttl: ttl)
            }
            offset = dataEnd
        }

        var currentName = normalizedName(host)
        var aliasTTL = UInt32.max
        var visitedNames: Set<String> = [currentName]
        for _ in 0..<8 {
            guard let alias = aliases[currentName] else { break }
            guard visitedNames.insert(alias.target).inserted else { return nil }
            aliasTTL = min(aliasTTL, alias.ttl)
            currentName = alias.target
        }

        var seenAddresses = Set<String>()
        let matchingRecords = addresses.filter { $0.owner == currentName }.filter {
            seenAddresses.insert($0.address).inserted
        }
        let selectedRecords = Array(matchingRecords.prefix(maximumAddresses))
        guard !selectedRecords.isEmpty else { return nil }

        let addressTTL = selectedRecords.map { min(aliasTTL, $0.ttl) }.min() ?? 0
        return PixivDirectDNSResolution(
            addresses: selectedRecords.map(\.address),
            ttl: TimeInterval(addressTTL)
        )
    }

    private static func readName(_ data: Data, at offset: Int) -> (name: String, nextOffset: Int)? {
        var cursor = offset
        var nextOffset: Int?
        var labels: [String] = []
        var visitedPointers = Set<Int>()
        var steps = 0

        while cursor < data.count, steps < 128 {
            steps += 1
            let length = Int(data[cursor])
            if length == 0 {
                if nextOffset == nil { nextOffset = cursor + 1 }
                guard let nextOffset else { return nil }
                return (labels.joined(separator: ".").lowercased(), nextOffset)
            }

            if length & 0xC0 == 0xC0 {
                guard cursor + 1 < data.count else { return nil }
                let pointer = ((length & 0x3F) << 8) | Int(data[cursor + 1])
                guard pointer < data.count, visitedPointers.insert(pointer).inserted else { return nil }
                if nextOffset == nil { nextOffset = cursor + 2 }
                cursor = pointer
                continue
            }

            guard length & 0xC0 == 0,
                  length <= 63,
                  cursor + 1 + length <= data.count else {
                return nil
            }
            let labelData = data[(cursor + 1)..<(cursor + 1 + length)]
            guard let label = String(data: labelData, encoding: .utf8), !label.contains(".") else {
                return nil
            }
            labels.append(label)
            cursor += length + 1
        }
        return nil
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= data.count else { return nil }
        return UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        return UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
    }
}

nonisolated private extension Data {
    var base64URLEncodedString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

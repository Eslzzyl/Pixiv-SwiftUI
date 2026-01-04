import Foundation
import Network
import Security
import Gzip

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@MainActor
final class DirectConnection: @unchecked Sendable {
    static let shared = DirectConnection()

    private let timeout: TimeInterval = 10

    private init() {}

    func request(
        endpoint: PixivEndpoint,
        path: String,
        method: String = "POST",
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let host = endpoint.host
        let ips = endpoint.getIPList()

        print("[DirectConnection] 请求: \(method) \(host)\(path), IPs: \(ips)")

        var lastError: Error?
        for ip in ips {
            print("[DirectConnection] 尝试 IP: \(ip):\(endpoint.port)")
            do {
                return try await performRequest(
                    ip: ip,
                    port: endpoint.port,
                    host: host,
                    path: path,
                    method: method,
                    headers: headers,
                    body: body
                )
            } catch {
                print("[DirectConnection] IP \(ip) 失败: \(error)")
                lastError = error
                continue
            }
        }

        if endpoint == .image {
            Task {
                await IpCacheManager.shared.refreshAll()
            }
        }

        throw lastError ?? NSError(
            domain: "PixivNetworkKit",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "All endpoints failed"]
        )
    }

    private func performRequest(
        ip: String,
        port: Int,
        host: String,
        path: String,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws -> (Data, HTTPURLResponse) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ip), port: NWEndpoint.Port(integerLiteral: UInt16(port)))

        let tlsOptions = NWProtocolTLS.Options()

        // 强制使用 HTTP/1.1，避免 ALPN 协商到 HTTP/2 导致 421 错误
        sec_protocol_options_add_tls_application_protocol(tlsOptions.securityProtocolOptions, "http/1.1")

        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { (_, sec_trust, completionHandler) in
            let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
            var certificateCount = 0
            var foundMatch = false

            if let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate] {
                certificateCount = certificates.count
                for cert in certificates {
                    if let summary = SecCertificateCopySubjectSummary(cert) as String? {
                        let lowerSummary = summary.lowercased()
                        if lowerSummary.contains("pixiv.net") || lowerSummary.contains("pximg.net") {
                            foundMatch = true
                            break
                        }
                    }
                }
            }

            if foundMatch {
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        }, .global())

        let parameters = NWParameters(tls: tlsOptions)

        let connection = NWConnection(to: endpoint, using: parameters)
        let responseBuffer = ResponseBuffer()

        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTimer = DispatchSource.makeTimerSource(queue: .global())
            timeoutTimer.schedule(deadline: .now() + timeout)

            let isFinished = AtomicBool(false)
            let finishLock = NSLock()

            @Sendable func finish(with result: Result<(Data, HTTPURLResponse), Error>) {
                if isFinished.compareAndSwap(expected: false, desired: true) {
                    finishLock.lock()
                    timeoutTimer.cancel()
                    connection.cancel()
                    continuation.resume(with: result)
                    finishLock.unlock()
                }
            }

            timeoutTimer.setEventHandler {
                print("[DirectConnection] 请求超时")
                finish(with: .failure(NSError(domain: "PixivNetworkKit", code: -3, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])))
            }
            timeoutTimer.resume()

            connection.stateUpdateHandler = { [weak self] state in
                guard self != nil else { return }

                switch state {
                case .ready:
                    print("[DirectConnection] 连接就绪，发送请求")
                    var request = "\(method) \(path) HTTP/1.1\r\n"
                    request += "Host: \(host)\r\n"
                    
                    // 基础请求头
                    var allHeaders = headers
                    
                    // 设置默认 User-Agent
                    if allHeaders["User-Agent"] == nil {
                        allHeaders["User-Agent"] = "PixivIOSApp/7.13.3 (iOS 14.6; iPhone12,1)"
                    }
                    
                    // 设置默认 App-OS 相关头
                    if allHeaders["App-OS"] == nil {
                        allHeaders["App-OS"] = "ios"
                    }
                    if allHeaders["App-OS-Version"] == nil {
                        allHeaders["App-OS-Version"] = "14.6"
                    }
                    if allHeaders["App-Version"] == nil {
                        allHeaders["App-Version"] = "7.13.3"
                    }
                    
                    if allHeaders["Accept-Encoding"] == nil {
                        allHeaders["Accept-Encoding"] = "gzip"
                    }
                    
                    if allHeaders["Connection"] == nil {
                        allHeaders["Connection"] = "close"
                    }

                    if allHeaders["Referer"] == nil && (host.contains("pixiv") || host.contains("pximg")) {
                        allHeaders["Referer"] = "https://www.pixiv.net/"
                    }

                    // 写入 Content-Length
                    let bodyLength = body?.count ?? 0
                    request += "Content-Length: \(bodyLength)\r\n"
                    
                    // 写入其他请求头，排除已手动处理的
                    let excludedHeaders = ["Host", "Content-Length"]
                    for (key, value) in allHeaders {
                        if !excludedHeaders.contains(key) {
                            request += "\(key): \(value)\r\n"
                        }
                    }
                    request += "\r\n"

                    var requestData = Data(request.utf8)
                    if let body = body {
                        requestData.append(body)
                    }

                    connection.send(content: requestData, completion: .contentProcessed { sendError in
                        if let error = sendError {
                            print("[DirectConnection] 发送请求失败: \(error)")
                            finish(with: .failure(error))
                        }
                    })

                case .failed(let error):
                    print("[DirectConnection] 连接失败: \(error)")
                    finish(with: .failure(error))

                case .cancelled:
                    print("[DirectConnection] 连接取消")
                    if isFinished.isTrue == false {
                        finish(with: .failure(NSError(domain: "PixivNetworkKit", code: -4, userInfo: [NSLocalizedDescriptionKey: "Connection cancelled"])))
                    }

                default:
                    break
                }
            }

            @Sendable func receiveNext() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                    if let data = data, !data.isEmpty {
                        Task {
                            await responseBuffer.append(data)
                        }
                    }

                    if let error = error {
                        print("[DirectConnection] 接收错误: \(error)")
                        finish(with: .failure(error))
                        return
                    }

                    if isComplete {
                        Task {
                            let data = await responseBuffer.data
                            if !data.isEmpty {
                                let parsed = self.parseHTTPResponse(data: data, host: host)
                                print("[DirectConnection] 响应状态码: \(parsed.response.statusCode)")
                                finish(with: .success((parsed.body, parsed.response)))
                            } else {
                                finish(with: .failure(NSError(
                                    domain: "PixivNetworkKit",
                                    code: -2,
                                    userInfo: [NSLocalizedDescriptionKey: "Empty response"]
                                )))
                            }
                        }
                        return
                    }

                    receiveNext()
                }
            }

            receiveNext()
            connection.start(queue: .main)
        }
    }

    nonisolated func parseHTTPResponse(data: Data, host: String) -> (body: Data, response: HTTPURLResponse) {
        let separator = Data("\r\n\r\n".utf8)
        let altSeparator = Data("\n\n".utf8)

        var headerData: Data
        var bodyData: Data

        if let range = data.range(of: separator) {
            headerData = data.subdata(in: 0..<range.lowerBound)
            bodyData = data.subdata(in: range.upperBound..<data.count)
        } else if let range = data.range(of: altSeparator) {
            headerData = data.subdata(in: 0..<range.lowerBound)
            bodyData = data.subdata(in: range.upperBound..<data.count)
        } else {
            headerData = data
            bodyData = Data()
        }

        let headerString = String(data: headerData, encoding: .utf8) ?? ""
        let headerLines = headerString.components(separatedBy: .newlines)

        var statusCode = 200
        var headerDict: [String: [String]] = [:]

        for (index, line) in headerLines.enumerated() {
            if index == 0 {
                let parts = line.split(separator: " ", maxSplits: 2)
                if parts.count >= 2 {
                    statusCode = Int(parts[1]) ?? 200
                }
            } else {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespaces).lowercased()
                    let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    if var existing = headerDict[key] {
                        existing.append(value)
                        headerDict[key] = existing
                    } else {
                        headerDict[key] = [value]
                    }
                }
            }
        }

        let flattenedHeaders: [String: String] = headerDict.mapValues { values in
            values.joined(separator: ", ")
        }

        let response = HTTPURLResponse(
            url: URL(string: "https://\(host)")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: flattenedHeaders
        ) ?? HTTPURLResponse()

        var finalBody = bodyData
        if headerDict["transfer-encoding"]?.first == "chunked" {
            finalBody = decodeChunkedData(bodyData)
        }

        let contentEncoding = headerDict["content-encoding"]?.first
        if contentEncoding == "gzip" {
            print("[DirectConnection] Content-Encoding: gzip, 原始大小: \(finalBody.count) bytes")
            do {
                let decompressed = try finalBody.gunzipped()
                print("[DirectConnection] gzip 解压成功: \(finalBody.count) -> \(decompressed.count) bytes")
                finalBody = decompressed
            } catch {
                print("[DirectConnection] gzip 解压失败: \(error)")
            }
        }

        return (finalBody, response)
    }

    nonisolated private func decodeChunkedData(_ data: Data) -> Data {
        var decoded = Data()
        var offset = 0

        while offset < data.count {
            var lineEnd = offset
            while lineEnd < data.count - 1 && !(data[lineEnd] == 0x0D && data[lineEnd+1] == 0x0A) {
                lineEnd += 1
            }

            if lineEnd >= data.count - 1 { break }

            let sizeData = data.subdata(in: offset..<lineEnd)
            guard let sizeString = String(data: sizeData, encoding: .utf8) else {
                break
            }

            let trimmedSizeString = sizeString.trimmingCharacters(in: .whitespaces)
            let semicolonIndex = trimmedSizeString.firstIndex(of: ";")
            let cleanSizeString = String(trimmedSizeString[..<(semicolonIndex ?? trimmedSizeString.endIndex)])

            guard let chunkSize = Int(cleanSizeString, radix: 16) else {
                break
            }

            offset = lineEnd + 2
            if chunkSize == 0 { break }

            let chunkDataEnd = offset + chunkSize
            if chunkDataEnd <= data.count {
                decoded.append(data.subdata(in: offset..<chunkDataEnd))
            }

            offset = chunkDataEnd + 2
        }

        return decoded
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
actor ResponseBuffer {
    private var storage = Data()

    func append(_ newData: Data) {
        storage.append(newData)
    }

    var data: Data {
        storage
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
final class AtomicBool: @unchecked Sendable {
    nonisolated private let valuePtr: UnsafeMutablePointer<Bool>
    nonisolated private let lock = NSLock()

    init(_ value: Bool = false) {
        valuePtr = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        valuePtr.pointee = value
    }

    deinit {
        valuePtr.deallocate()
    }

    nonisolated func compareAndSwap(expected: Bool, desired: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if valuePtr.pointee == expected {
            valuePtr.pointee = desired
            return true
        }
        return false
    }

    nonisolated var isTrue: Bool {
        lock.lock()
        defer { lock.unlock() }
        return valuePtr.pointee
    }
}

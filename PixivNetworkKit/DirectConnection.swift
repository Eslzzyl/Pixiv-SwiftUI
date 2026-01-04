import Foundation
import Network
import Security
import Gzip

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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
        let ips = endpoint.ips

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
                for (idx, cert) in certificates.enumerated() {
                    if let summary = SecCertificateCopySubjectSummary(cert) as String? {
                        let lowerSummary = summary.lowercased()
                        print("[DirectConnection] 证书 \(idx + 1)/\(certificateCount): \(summary)")
                        // 检查是否包含 pixiv.net 或 pximg.net，以支持 API 和图片直连
                        if lowerSummary.contains("pixiv.net") || lowerSummary.contains("pximg.net") {
                            print("[DirectConnection] 证书验证通过: \(summary)")
                            foundMatch = true
                            break
                        }
                    } else {
                        print("[DirectConnection] 证书 \(idx + 1)/\(certificateCount): 无法获取摘要")
                    }
                }
            } else {
                print("[DirectConnection] 错误: 无法获取证书链")
            }
            
            if foundMatch {
                completionHandler(true)
            } else {
                print("[DirectConnection] 证书验证失败（共 \(certificateCount) 个证书）")
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

                print("[DirectConnection] 连接状态变化: \(state)")

                switch state {
                case .ready:
                    print("[DirectConnection] 连接就绪，发送请求")
                    var request = "\(method) \(path) HTTP/1.1\r\n"
                    request += "Host: \(host)\r\n"
                    request += "Content-Length: \(body?.count ?? 0)\r\n"
                    request += "Connection: close\r\n"
                    request += "Accept-Encoding: gzip\r\n"

                    if headers["Referer"] == nil && (host.contains("pixiv") || host.contains("pximg")) {
                        request += "Referer: https://www.pixiv.net/\r\n"
                    }

                    for (key, value) in headers {
                        request += "\(key): \(value)\r\n"
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
                        } else {
                            print("[DirectConnection] 请求发送成功")
                        }
                    })

                case .failed(let error):
                    print("[DirectConnection] 连接失败: \(error)")
                    if let nwError = error as? NWError {
                        print("[DirectConnection] NWError 详情: \(nwError.debugDescription)")
                    }
                    finish(with: .failure(error))

                case .cancelled:
                    print("[DirectConnection] 连接取消")
                    if isFinished.isTrue == false {
                        finish(with: .failure(NSError(domain: "PixivNetworkKit", code: -4, userInfo: [NSLocalizedDescriptionKey: "Connection cancelled"])))
                    }

                case .waiting(let error):
                    print("[DirectConnection] 连接等待中: \(error)")

                default:
                    break
                }
            }

            @Sendable func receiveNext() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                    if let data = data, !data.isEmpty {
                        print("[DirectConnection] 收到数据: \(data.count) bytes")
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
                        print("[DirectConnection] 响应接收完成")
                        Task {
                            let data = await responseBuffer.data
                            if !data.isEmpty {
                                print("[DirectConnection] 解析响应，数据大小: \(data.count) bytes")
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

    private func validateCertificate(secTrust: Any, host: String, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
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

        if headerDict["content-encoding"]?.first == "gzip", let decompressed = try? finalBody.gunzipped() {
            finalBody = decompressed
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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
actor ResponseBuffer {
    private var storage = Data()

    func append(_ newData: Data) {
        storage.append(newData)
    }

    var data: Data {
        storage
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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

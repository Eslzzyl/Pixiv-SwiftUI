import Foundation
import Network
import Security
import os.log

nonisolated enum PixivDirectConnectionError: LocalizedError {
    case unsupportedHost
    case invalidRequest
    case invalidResponse
    case incompleteResponse
    case responseTooLarge
    case requestTooLarge
    case timedOut
    case frameUnexpected
    case messageError
    case idError
    case qpackDecompressionFailed
    case transportFailure(String, isRetryable: Bool)
    case allEndpointsFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedHost:
            return "不支持的 HTTP/3 直连域名"
        case .invalidRequest:
            return "无效的 HTTP/3 直连请求"
        case .invalidResponse:
            return "无效的 HTTP/3 直连响应"
        case .incompleteResponse:
            return "HTTP/3 直连响应不完整"
        case .responseTooLarge:
            return "HTTP/3 直连响应过大"
        case .requestTooLarge:
            return "HTTP/3 直连请求过大"
        case .timedOut:
            return "HTTP/3 直连请求超时"
        case .frameUnexpected:
            return "Unexpected HTTP/3 frame sequence"
        case .messageError:
            return "Malformed HTTP/3 response"
        case .idError:
            return "Invalid HTTP/3 push identifier"
        case .qpackDecompressionFailed:
            return "QPACK response decoding failed"
        case let .transportFailure(message, _):
            return message
        case .allEndpointsFailed:
            return "所有 HTTP/3 直连节点均失败"
        }
    }

    var quicConnectionErrorCode: UInt64? {
        switch self {
        case .frameUnexpected:
            0x0105
        case .incompleteResponse:
            0x0106
        case .idError:
            0x0108
        case .qpackDecompressionFailed:
            0x0200
        default:
            nil
        }
    }

    var quicStreamErrorCode: UInt64? {
        switch self {
        case .messageError:
            0x010e
        default:
            nil
        }
    }

    var isRetryable: Bool {
        switch self {
        case .timedOut, .allEndpointsFailed:
            true
        case let .transportFailure(_, isRetryable):
            isRetryable
        default:
            false
        }
    }

    static func fromTransportError(_ error: NWError) -> Self {
        .transportFailure(error.localizedDescription, isRetryable: error.isRetryableForPixivRequest)
    }
}

nonisolated struct PixivRequestDeadline: Sendable {
    private let expiresAtNanoseconds: UInt64

    init(timeoutInterval: TimeInterval) {
        let requestedInterval = timeoutInterval.isFinite && timeoutInterval > 0
            ? min(timeoutInterval, 60)
            : 60
        expiresAtNanoseconds = DispatchTime.now().uptimeNanoseconds
            + UInt64(requestedInterval * 1_000_000_000)
    }

    var remainingTimeInterval: TimeInterval {
        let now = DispatchTime.now().uptimeNanoseconds
        guard expiresAtNanoseconds > now else { return 0 }
        return TimeInterval(expiresAtNanoseconds - now) / 1_000_000_000
    }

    func apply(to request: inout URLRequest) throws {
        let remaining = remainingTimeInterval
        guard remaining > 0 else {
            throw PixivDirectConnectionError.timedOut
        }

        let requestTimeout = request.timeoutInterval.isFinite && request.timeoutInterval > 0
            ? request.timeoutInterval
            : remaining
        request.timeoutInterval = min(requestTimeout, remaining)
    }

    func check() throws {
        guard remainingTimeInterval > 0 else {
            throw PixivDirectConnectionError.timedOut
        }
    }
}

nonisolated private extension NWError {
    var isRetryableForPixivRequest: Bool {
        guard case let .posix(code) = self else { return false }

        return switch code {
        case .ETIMEDOUT, .ENETUNREACH, .EHOSTUNREACH, .ENETDOWN,
             .ECONNRESET, .ECONNABORTED, .ECONNREFUSED, .EPIPE, .EAGAIN, .EINTR:
            true
        default:
            false
        }
    }
}

private enum PixivDirectEndpointCatalog {
    private static let cloudflareAddresses = [
        "104.18.42.239",
        "172.64.145.17",
    ]

    private static let pximgAddresses = [
        "210.140.139.129",
        "210.140.139.130",
        "210.140.139.131",
        "210.140.139.132",
        "210.140.139.133",
        "210.140.139.134",
        "210.140.139.135",
        "210.140.139.136",
        "210.140.139.137",
        "210.140.139.138",
    ]

    static func addresses(for host: String) -> [String] {
        if PixivNetworkConfiguration.isPixivImageHost(host) {
            return pximgAddresses
        }

        if PixivNetworkConfiguration.isPixivHost(host) {
            return cloudflareAddresses
        }

        return []
    }
}

private actor PixivDirectEndpointHealth {
    private var scores: [String: Double] = [:]

    func ordered(_ addresses: [String]) -> [String] {
        addresses.sorted { lhs, rhs in
            (scores[lhs] ?? 1) > (scores[rhs] ?? 1)
        }
    }

    func reportSuccess(_ address: String) {
        scores[address] = min(1, (scores[address] ?? 1) + 0.1)
    }

    func reportFailure(_ address: String) {
        scores[address] = max(0.1, (scores[address] ?? 1) - 0.2)
    }
}

nonisolated private final class PixivDirectResponse: @unchecked Sendable {
    let data: Data
    let response: HTTPURLResponse
    let negotiatedProtocol: String

    init(data: Data, response: HTTPURLResponse, negotiatedProtocol: String) {
        self.data = data
        self.response = response
        self.negotiatedProtocol = negotiatedProtocol
    }
}

final class PixivDirectConnection: @unchecked Sendable {
    static let shared = PixivDirectConnection()

    private let endpointHealth = PixivDirectEndpointHealth()
    private let maxResponseBytes = 128 * 1024 * 1024
    private let maxRequestBytes = 32 * 1024 * 1024

    private init() {}

    func data(
        for request: URLRequest,
        deadline: PixivRequestDeadline? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let deadline = deadline ?? PixivRequestDeadline(timeoutInterval: request.timeoutInterval)
        guard let url = request.url,
              let host = url.host,
              url.scheme?.lowercased() == "https" else {
            throw PixivDirectConnectionError.invalidRequest
        }

        try deadline.check()
        let addresses = await endpointHealth.ordered(PixivDirectEndpointCatalog.addresses(for: host))
        guard !addresses.isEmpty else {
            throw PixivDirectConnectionError.unsupportedHost
        }

        let method = request.httpMethod?.uppercased() ?? "GET"
        let payload = try makeRequestPayload(request, host: host)
        var lastError: Error?

        for address in addresses {
            let remainingTime = deadline.remainingTimeInterval
            guard remainingTime > 0 else {
                throw PixivDirectConnectionError.timedOut
            }
            let timeout = min(remainingTime, 15)

            do {
                let result = try await PixivHTTP3Session(
                    requestURL: url,
                    requestMethod: method,
                    host: host,
                    address: address,
                    payload: payload,
                    timeout: timeout,
                    maxResponseBytes: maxResponseBytes
                ).run()
                try deadline.check()
                await endpointHealth.reportSuccess(address)
                Logger.network.debug(
                    "HTTP/3 直连传输完成 host=\(host, privacy: .public) endpoint=\(address, privacy: .public) protocol=\(result.negotiatedProtocol, privacy: .public) proxy=disabled sni=\(host, privacy: .public) status=\(result.response.statusCode)"
                )
                return (result.data, result.response)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                await endpointHealth.reportFailure(address)
                if deadline.remainingTimeInterval == 0 {
                    throw PixivDirectConnectionError.timedOut
                }
                lastError = error
                Logger.network.debug(
                    "HTTP/3 直连节点失败 host=\(host, privacy: .public) endpoint=\(address, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                )
            }
        }

        throw lastError ?? PixivDirectConnectionError.allEndpointsFailed
    }

    private func makeRequestPayload(_ request: URLRequest, host: String) throws -> Data {
        guard let url = request.url else {
            throw PixivDirectConnectionError.invalidRequest
        }

        let method = request.httpMethod?.uppercased() ?? "GET"
        let encodedPath = url.path(percentEncoded: true)
        let path = encodedPath.isEmpty ? "/" : encodedPath
        let target = if let query = url.query(percentEncoded: true), !query.isEmpty {
            "\(path)?\(query)"
        } else {
            path
        }
        let body = request.httpBody ?? Data()
        var headers = normalizedHeaders(request.allHTTPHeaderFields ?? [:])

        headers.removeValue(forKey: "host")
        headers.removeValue(forKey: "connection")
        headers.removeValue(forKey: "proxy-connection")
        headers.removeValue(forKey: "transfer-encoding")
        headers["accept-encoding"] = "identity"

        if headers["user-agent"] == nil {
            headers["user-agent"] = "PixivIOSApp/7.13.3 (iOS 14.6; iPhone13,2)"
        }

        if !body.isEmpty || headers["content-length"] != nil {
            headers["content-length"] = String(body.count)
        }

        var authority = host
        if let port = url.port, port != 443 {
            authority += ":\(port)"
        }

        let headerBlock = PixivQPACKEncoder.encode(
            method: method,
            scheme: url.scheme ?? "https",
            authority: authority,
            path: target,
            headers: headers
        )

        var payload = PixivHTTP3Frame.make(type: 0x01, payload: headerBlock)
        if !body.isEmpty {
            payload.append(PixivHTTP3Frame.make(type: 0x00, payload: body))
        }

        guard payload.count <= maxRequestBytes else {
            throw PixivDirectConnectionError.requestTooLarge
        }
        return payload
    }

    private func normalizedHeaders(_ headers: [String: String]) -> [String: String] {
        var normalized: [String: String] = [:]
        for (key, value) in headers {
            normalized[key.lowercased()] = value
        }
        return normalized
    }
}

nonisolated private final class PixivHTTP3Session: @unchecked Sendable {
    private let requestURL: URL
    private let host: String
    private let address: String
    private let payload: Data
    private let timeout: TimeInterval
    private let responseParser: PixivHTTP3ResponseParser
    private let queue: DispatchQueue
    private let lock = NSLock()

    private var group: NWConnectionGroup?
    private var requestConnection: NWConnection?
    private var streamConnections: [NWConnection] = []
    private var continuation: CheckedContinuation<PixivDirectResponse, Error>?
    private var timeoutWorkItem: DispatchWorkItem?
    private var isFinished = false
    private var didStartStreams = false
    private var requestReady = false
    private var requestSent = false
    private var responseReceiveStarted = false
    private var streamReady = [false, false, false]
    private var streamPayloadSent = [false, false, false]
    private var streamPayloadProcessed = [false, false, false]

    init(
        requestURL: URL,
        requestMethod: String,
        host: String,
        address: String,
        payload: Data,
        timeout: TimeInterval,
        maxResponseBytes: Int
    ) {
        self.requestURL = requestURL
        self.host = host
        self.address = address
        self.payload = payload
        self.timeout = timeout
        self.responseParser = PixivHTTP3ResponseParser(
            requestURL: requestURL,
            requestMethod: requestMethod,
            maxResponseBytes: maxResponseBytes
        )
        self.queue = DispatchQueue(label: "com.pixiv.http3.\(address).\(UUID().uuidString)")
    }

    func run() async throws -> PixivDirectResponse {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PixivDirectResponse, Error>) in
                lock.lock()
                self.continuation = continuation
                lock.unlock()
                start()
            }
        } onCancel: {
            finish(.failure(CancellationError()))
        }
    }

    private func start() {
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.finish(.failure(PixivDirectConnectionError.timedOut))
        }

        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        self.timeoutWorkItem = timeoutWorkItem
        lock.unlock()

        queue.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)

        let group = makeGroup()
        lock.lock()
        self.group = group
        lock.unlock()

        group.newConnectionHandler = { [weak self] connection in
            self?.handleIncomingConnection(connection)
        }
        group.stateUpdateHandler = { [weak self] state in
            self?.handleGroupState(state)
        }
        group.start(queue: queue)
    }

    private func makeGroup() -> NWConnectionGroup {
        let options = NWProtocolQUIC.Options(alpn: ["h3"])
        options.direction = .bidirectional
        options.initialMaxData = 8 * 1024 * 1024
        options.initialMaxStreamsBidirectional = 16
        options.initialMaxStreamsUnidirectional = 16
        options.initialMaxStreamDataBidirectionalLocal = 2 * 1024 * 1024
        options.initialMaxStreamDataBidirectionalRemote = 2 * 1024 * 1024
        options.initialMaxStreamDataUnidirectional = 2 * 1024 * 1024
        options.idleTimeout = max(1, Int(timeout * 1_000))

        let serverName = host
        sec_protocol_options_set_tls_server_name(options.securityProtocolOptions, serverName)
        sec_protocol_options_set_verify_block(
            options.securityProtocolOptions,
            { _, trustRef, completionHandler in
                let trust = sec_trust_copy_ref(trustRef).takeRetainedValue()
                let policy = SecPolicyCreateSSL(true, serverName as CFString)
                SecTrustSetPolicies(trust, policy)
                var error: CFError?
                completionHandler(SecTrustEvaluateWithError(trust, &error))
            },
            queue
        )

        let parameters = NWParameters(quic: options)
        parameters.preferNoProxies = true
        let privacyContext = NWParameters.PrivacyContext(description: "Pixiv HTTP/3 direct mode")
        privacyContext.proxyConfigurations = [PixivNetworkConfiguration.makeNoProxyConfiguration()]
        parameters.setPrivacyContext(privacyContext)

        return NWConnectionGroup(
            with: NWMultiplexGroup(
                to: .hostPort(host: NWEndpoint.Host(address), port: .https)
            ),
            using: parameters
        )
    }

    private func handleGroupState(_ state: NWConnectionGroup.State) {
        switch state {
        case .ready:
            startStreamsIfNeeded()
        case let .failed(error):
            finish(.failure(PixivDirectConnectionError.fromTransportError(error)))
        case .cancelled:
            finish(.failure(CancellationError()))
        case .setup, .waiting:
            break
        @unknown default:
            break
        }
    }

    private func startStreamsIfNeeded() {
        lock.lock()
        guard !didStartStreams, !isFinished, let group else {
            lock.unlock()
            return
        }
        didStartStreams = true
        lock.unlock()

        guard let request = NWConnection(from: group) else {
            finish(.failure(PixivDirectConnectionError.transportFailure(
                "Unable to create HTTP/3 request stream",
                isRetryable: false
            )))
            return
        }
        let controlOptions = NWProtocolQUIC.Options()
        controlOptions.direction = .unidirectional
        let control = NWConnection(from: group, using: controlOptions)
        let encoder = NWConnection(from: group, using: controlOptions)
        let decoder = NWConnection(from: group, using: controlOptions)

        guard let control, let encoder, let decoder else {
            finish(.failure(PixivDirectConnectionError.transportFailure(
                "Unable to create HTTP/3 streams",
                isRetryable: false
            )))
            return
        }

        lock.lock()
        requestConnection = request
        streamConnections = [control, encoder, decoder]
        lock.unlock()

        configureRequestConnection(request)
        configureStreamConnection(control, index: 0, payload: makeControlPayload())
        configureStreamConnection(encoder, index: 1, payload: Data([0x02]))
        configureStreamConnection(decoder, index: 2, payload: Data([0x03]))

        request.start(queue: queue)
        control.start(queue: queue)
        encoder.start(queue: queue)
        decoder.start(queue: queue)
    }

    private func makeControlPayload() -> Data {
        var settings = Data()
        settings.append(PixivHTTP3Frame.encodeInteger(0x01))
        settings.append(PixivHTTP3Frame.encodeInteger(0))
        settings.append(PixivHTTP3Frame.encodeInteger(0x07))
        settings.append(PixivHTTP3Frame.encodeInteger(0))

        var payload = Data([0x00])
        payload.append(PixivHTTP3Frame.make(type: 0x04, payload: settings))
        return payload
    }

    private func configureRequestConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                self.lock.lock()
                self.requestReady = true
                self.lock.unlock()
                self.receiveResponseIfNeeded(from: connection)
                self.sendRequestIfReady()
            case let .failed(error):
                self.finish(.failure(PixivDirectConnectionError.fromTransportError(error)))
            case .cancelled:
                self.finish(.failure(CancellationError()))
            default:
                break
            }
        }
    }

    private func configureStreamConnection(_ connection: NWConnection, index: Int, payload: Data) {
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                self.lock.lock()
                let shouldSend = !self.streamPayloadSent[index]
                if shouldSend {
                    self.streamReady[index] = true
                    self.streamPayloadSent[index] = true
                }
                self.lock.unlock()
                if shouldSend {
                    self.sendStreamPayload(payload, index: index, on: connection)
                }
                self.sendRequestIfReady()
            case let .failed(error):
                self.finish(.failure(PixivDirectConnectionError.fromTransportError(error)))
            case .cancelled:
                self.finish(.failure(CancellationError()))
            default:
                break
            }
        }
    }

    private func sendStreamPayload(_ payload: Data, index: Int, on connection: NWConnection) {
        connection.send(
            content: payload,
            contentContext: .defaultMessage,
            isComplete: false,
            completion: .contentProcessed { [weak self] error in
                if let error {
                    self?.finish(.failure(PixivDirectConnectionError.fromTransportError(error)))
                } else {
                    self?.lock.lock()
                    self?.streamPayloadProcessed[index] = true
                    self?.lock.unlock()
                    self?.sendRequestIfReady()
                }
            }
        )
    }

    private func sendRequestIfReady() {
        lock.lock()
        guard !isFinished,
              requestReady,
              !requestSent,
              streamReady.allSatisfy({ $0 }),
              streamPayloadProcessed.allSatisfy({ $0 }),
              let connection = requestConnection else {
            lock.unlock()
            return
        }
        requestSent = true
        lock.unlock()

        connection.send(
            content: payload,
            contentContext: .defaultMessage,
            isComplete: false,
            completion: .contentProcessed { [weak self, weak connection] error in
                guard let self, let connection else { return }
                if let error {
                    self.finish(.failure(PixivDirectConnectionError.fromTransportError(error)))
                    return
                }
                connection.send(
                    content: nil,
                    contentContext: .finalMessage,
                    isComplete: true,
                    completion: .contentProcessed { [weak self] error in
                        if let error {
                            self?.finish(.failure(PixivDirectConnectionError.fromTransportError(error)))
                        }
                    }
                )
            }
        )
    }

    private func receiveResponseIfNeeded(from connection: NWConnection) {
        lock.lock()
        guard !responseReceiveStarted, !isFinished else {
            lock.unlock()
            return
        }
        responseReceiveStarted = true
        lock.unlock()
        receiveNext(from: connection)
    }

    private func receiveNext(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }

            do {
                if let data, !data.isEmpty {
                    try self.responseParser.append(data)
                }

                if let error {
                    self.finish(.failure(PixivDirectConnectionError.fromTransportError(error)))
                } else if isComplete {
                    self.finish(.success(try self.responseParser.finish()))
                } else {
                    self.receiveNext(from: connection)
                }
            } catch {
                Logger.network.error(
                    "HTTP/3 直连响应解析失败 host=\(self.host, privacy: .public) error=\(error.localizedDescription, privacy: .public) \(self.responseParser.diagnosticSummary(), privacy: .public)"
                )
                let directError = error as? PixivDirectConnectionError
                self.finish(
                    .failure(error),
                    quicConnectionErrorCode: directError?.quicConnectionErrorCode,
                    quicStreamErrorCode: directError?.quicStreamErrorCode
                )
            }
        }
    }

    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                self.discardIncomingData(from: connection)
            case let .failed(error):
                Logger.network.debug(
                    "HTTP/3 直连服务端单向流结束 error=\(error.localizedDescription, privacy: .public)"
                )
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func discardIncomingData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self, weak connection] _, _, isComplete, error in
            guard let self, let connection else { return }
            guard !isComplete, error == nil else { return }
            self.discardIncomingData(from: connection)
        }
    }

    private func finish(
        _ result: Result<PixivDirectResponse, Error>,
        quicConnectionErrorCode: UInt64? = nil,
        quicStreamErrorCode: UInt64? = nil
    ) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        let continuation = self.continuation
        let timeoutWorkItem = self.timeoutWorkItem
        let group = self.group
        let requestConnection = self.requestConnection
        let streamConnections = self.streamConnections
        self.continuation = nil
        lock.unlock()

        if let metadata = requestConnection?.metadata(definition: NWProtocolQUIC.definition) as? NWProtocolQUIC.Metadata {
            if let quicConnectionErrorCode {
                metadata.applicationError = NWProtocolQUIC.ApplicationError(code: quicConnectionErrorCode, reason: nil)
            }
            if let quicStreamErrorCode {
                metadata.streamApplicationErrorCode = quicStreamErrorCode
            }
        }
        timeoutWorkItem?.cancel()
        requestConnection?.cancel()
        streamConnections.forEach { $0.cancel() }
        group?.cancel()
        continuation?.resume(with: result)
    }
}

nonisolated private enum PixivHTTP3Frame {
    static func make(type: UInt64, payload: Data) -> Data {
        var result = encodeInteger(type)
        result.append(encodeInteger(UInt64(payload.count)))
        result.append(payload)
        return result
    }

    static func encodeInteger(_ value: UInt64) -> Data {
        if value < 64 {
            return Data([UInt8(value)])
        }
        if value < 16_384 {
            return Data([
                UInt8((value >> 8) | 0x40),
                UInt8(value & 0xff),
            ])
        }
        if value < 1_073_741_824 {
            return Data([
                UInt8((value >> 24) | 0x80),
                UInt8((value >> 16) & 0xff),
                UInt8((value >> 8) & 0xff),
                UInt8(value & 0xff),
            ])
        }
        return Data([
            UInt8((value >> 56) | 0xc0),
            UInt8((value >> 48) & 0xff),
            UInt8((value >> 40) & 0xff),
            UInt8((value >> 32) & 0xff),
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff),
        ])
    }
}

nonisolated private enum PixivQPACKEncoder {
    static func encode(
        method: String,
        scheme: String,
        authority: String,
        path: String,
        headers: [String: String]
    ) -> Data {
        var result = Data([0x00, 0x00])

        if let index = staticMethodIndex(method) {
            result.append(encodePrefixedInteger(index, prefix: 0xc0, prefixBits: 6))
        } else {
            appendLiteralHeader(&result, name: ":method", value: method, neverIndex: false)
        }

        if scheme == "https" {
            result.append(encodePrefixedInteger(23, prefix: 0xc0, prefixBits: 6))
        } else if scheme == "http" {
            result.append(encodePrefixedInteger(22, prefix: 0xc0, prefixBits: 6))
        } else {
            appendLiteralHeader(&result, name: ":scheme", value: scheme, neverIndex: false)
        }

        appendLiteralNameReference(&result, staticNameIndex: 0, value: authority, neverIndex: false)
        if path == "/" {
            result.append(encodePrefixedInteger(1, prefix: 0xc0, prefixBits: 6))
        } else {
            appendLiteralNameReference(&result, staticNameIndex: 1, value: path, neverIndex: false)
        }

        for key in headers.keys.sorted() {
            guard let value = headers[key], !key.isEmpty else { continue }
            appendLiteralHeader(
                &result,
                name: key,
                value: value,
                neverIndex: key == "authorization" || key == "cookie" || key == "set-cookie"
            )
        }

        return result
    }

    private static func staticMethodIndex(_ method: String) -> UInt64? {
        switch method {
        case "CONNECT": return 15
        case "DELETE": return 16
        case "GET": return 17
        case "HEAD": return 18
        case "OPTIONS": return 19
        case "POST": return 20
        case "PUT": return 21
        default: return nil
        }
    }

    private static func appendLiteralNameReference(
        _ data: inout Data,
        staticNameIndex: UInt64,
        value: String,
        neverIndex: Bool
    ) {
        let prefix: UInt8 = neverIndex ? 0x58 : 0x50
        data.append(encodePrefixedInteger(staticNameIndex, prefix: prefix, prefixBits: 4))
        appendString(&data, value: value, prefixBits: 7)
    }

    private static func appendLiteralHeader(
        _ data: inout Data,
        name: String,
        value: String,
        neverIndex: Bool
    ) {
        let prefix: UInt8 = neverIndex ? 0x30 : 0x20
        let nameData = Data(name.utf8)
        data.append(encodePrefixedInteger(UInt64(nameData.count), prefix: prefix, prefixBits: 3))
        data.append(nameData)
        appendString(&data, value: value, prefixBits: 7)
    }

    private static func appendString(_ data: inout Data, value: String, prefixBits: Int) {
        let valueData = Data(value.utf8)
        data.append(encodePrefixedInteger(UInt64(valueData.count), prefix: 0, prefixBits: prefixBits))
        data.append(valueData)
    }

    private static func encodePrefixedInteger(_ value: UInt64, prefix: UInt8, prefixBits: Int) -> Data {
        let limit = (UInt64(1) << UInt64(prefixBits)) - 1
        if value < limit {
            return Data([prefix | UInt8(value)])
        }

        var result = Data([prefix | UInt8(limit)])
        var remaining = value - limit
        while remaining >= 128 {
            result.append(UInt8((remaining & 0x7f) | 0x80))
            remaining >>= 7
        }
        result.append(UInt8(remaining))
        return result
    }
}

nonisolated private final class PixivHTTP3ResponseParser: @unchecked Sendable {
    private enum ResponsePhase: Equatable {
        case awaitingFinalHeaders
        case body
        case trailers
    }

    private struct HeaderBlock {
        let statusCode: Int?
        let fields: [(name: String, value: String)]
    }

    private let requestURL: URL
    private let requestMethod: String
    private let maxResponseBytes: Int
    private var buffer = Data()
    private var body = Data()
    private var headers: [String: String] = [:]
    private var statusCode: Int?
    private var contentLength: UInt64?
    private var responseForbidsContent = false
    private var responsePhase = ResponsePhase.awaitingFinalHeaders

    init(requestURL: URL, requestMethod: String, maxResponseBytes: Int) {
        self.requestURL = requestURL
        self.requestMethod = requestMethod
        self.maxResponseBytes = maxResponseBytes
    }

    func append(_ data: Data) throws {
        buffer.append(data)
        guard buffer.count + body.count <= maxResponseBytes else {
            throw PixivDirectConnectionError.responseTooLarge
        }
        try parseAvailableFrames()
    }

    func finish() throws -> PixivDirectResponse {
        try parseAvailableFrames()
        guard buffer.isEmpty else {
            throw PixivDirectConnectionError.incompleteResponse
        }
        guard let statusCode else { throw PixivDirectConnectionError.messageError }
        if !responseForbidsContent, let contentLength, contentLength != UInt64(body.count) {
            throw PixivDirectConnectionError.messageError
        }
        guard let response = HTTPURLResponse(
            url: requestURL,
            statusCode: statusCode,
            httpVersion: "HTTP/3",
            headerFields: headers
        ) else {
            throw PixivDirectConnectionError.invalidResponse
        }
        return PixivDirectResponse(data: body, response: response, negotiatedProtocol: "h3")
    }

    func diagnosticSummary() -> String {
        let prefix = buffer.prefix(32).map { String(format: "%02x", $0) }.joined()
        return "bufferBytes=\(buffer.count) bodyBytes=\(body.count) status=\(statusCode.map(String.init) ?? "nil") prefix=\(prefix)"
    }

    private func parseAvailableFrames() throws {
        var offset = 0

        while offset < buffer.count {
            let frameStart = offset
            guard let type = decodeInteger(in: buffer, offset: &offset),
                  let length = decodeInteger(in: buffer, offset: &offset),
                  length <= UInt64(Int.max),
                  buffer.count - offset >= Int(length) else {
                offset = frameStart
                break
            }

            let end = offset + Int(length)
            let payload = buffer.subdata(in: offset..<end)
            switch type {
            case 0x00:
                guard responsePhase == .body else {
                    throw PixivDirectConnectionError.frameUnexpected
                }
                guard !responseForbidsContent else {
                    throw PixivDirectConnectionError.messageError
                }
                body.append(payload)
                guard body.count <= maxResponseBytes else {
                    throw PixivDirectConnectionError.responseTooLarge
                }
                if let contentLength, UInt64(body.count) > contentLength {
                    throw PixivDirectConnectionError.messageError
                }
            case 0x01:
                try processHeaderBlock(payload)
            case 0x02, 0x03, 0x04, 0x06, 0x07, 0x08, 0x09, 0x0d:
                throw PixivDirectConnectionError.frameUnexpected
            case 0x05:
                throw PixivDirectConnectionError.idError
            default:
                break
            }
            offset = end
        }

        if offset > 0 {
            buffer.removeSubrange(0..<offset)
        }
    }

    private func processHeaderBlock(_ payload: Data) throws {
        guard responsePhase != .trailers else {
            throw PixivDirectConnectionError.frameUnexpected
        }

        let headerBlock = try decodeHeaderBlock(payload)
        guard let blockStatus = headerBlock.statusCode else {
            guard responsePhase == .body else {
                throw PixivDirectConnectionError.messageError
            }
            guard !responseForbidsContent else {
                throw PixivDirectConnectionError.messageError
            }
            guard !headerBlock.fields.contains(where: { $0.name == "content-length" }) else {
                throw PixivDirectConnectionError.messageError
            }
            responsePhase = .trailers
            return
        }

        guard responsePhase == .awaitingFinalHeaders, statusCode == nil else {
            throw PixivDirectConnectionError.messageError
        }
        if (100..<200).contains(blockStatus) {
            guard blockStatus != 101,
                  !headerBlock.fields.contains(where: { $0.name == "content-length" }) else {
                throw PixivDirectConnectionError.messageError
            }
            return
        }

        statusCode = blockStatus
        responsePhase = .body
        responseForbidsContent = requestMethod == "HEAD" || blockStatus == 204 || blockStatus == 304
        contentLength = try parseContentLength(headerBlock.fields)
        guard blockStatus != 204 || contentLength == nil else {
            throw PixivDirectConnectionError.messageError
        }
        for field in headerBlock.fields where field.name != ":status" {
            headers[field.name] = field.value
        }
    }

    private func decodeHeaderBlock(_ payload: Data) throws -> HeaderBlock {
        var offset = 0
        guard let requiredInsertCount = decodePrefixedInteger(in: payload, offset: &offset, prefixBits: 8),
              requiredInsertCount == 0,
              offset < payload.count else {
            throw PixivDirectConnectionError.qpackDecompressionFailed
        }

        let baseSign = payload[offset] & 0x80 != 0
        guard let deltaBase = decodePrefixedInteger(in: payload, offset: &offset, prefixBits: 7),
              !baseSign,
              deltaBase == 0 else {
            throw PixivDirectConnectionError.qpackDecompressionFailed
        }

        var fields: [(name: String, value: String)] = []
        while offset < payload.count {
            let first = payload[offset]
            if first & 0x80 != 0 {
                guard let index = decodePrefixedInteger(in: payload, offset: &offset, prefixBits: 6) else {
                    throw PixivDirectConnectionError.qpackDecompressionFailed
                }
                guard first & 0x40 != 0, let entry = staticEntry(index: index) else {
                    throw PixivDirectConnectionError.qpackDecompressionFailed
                }
                fields.append(entry)
                continue
            }

            if first & 0xc0 == 0x40 {
                let isStatic = first & 0x10 != 0
                guard let index = decodePrefixedInteger(in: payload, offset: &offset, prefixBits: 4) else {
                    throw PixivDirectConnectionError.qpackDecompressionFailed
                }
                guard isStatic, let name = staticEntry(index: index)?.name else {
                    throw PixivDirectConnectionError.qpackDecompressionFailed
                }
                let value = try decodeString(in: payload, offset: &offset, prefixBits: 7)
                fields.append((name: name, value: value))
                continue
            }

            if first & 0xe0 == 0x20 {
                let name = try decodeString(in: payload, offset: &offset, prefixBits: 3)
                let value = try decodeString(in: payload, offset: &offset, prefixBits: 7)
                fields.append((name: name, value: value))
                continue
            }

            throw PixivDirectConnectionError.qpackDecompressionFailed
        }

        return try validateHeaderBlock(fields)
    }

    private func validateHeaderBlock(_ fields: [(name: String, value: String)]) throws -> HeaderBlock {
        var statusCode: Int?
        var regularFields: [(name: String, value: String)] = []
        var didReadRegularField = false

        for field in fields {
            if field.name.hasPrefix(":") {
                guard field.name == ":status",
                      statusCode == nil,
                      !didReadRegularField,
                      field.value.utf8.count == 3,
                      field.value.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                      let parsedStatus = Int(field.value),
                      (100...599).contains(parsedStatus) else {
                    throw PixivDirectConnectionError.messageError
                }
                statusCode = parsedStatus
            } else {
                let fieldName = field.name.utf8
                guard !fieldName.isEmpty,
                      field.name == field.name.lowercased(),
                      fieldName.allSatisfy(Self.isFieldNameCharacter),
                      field.value.utf8.allSatisfy(Self.isValidFieldValue),
                      !Self.connectionSpecificFieldNames.contains(field.name),
                      field.name != "te" else {
                    throw PixivDirectConnectionError.messageError
                }
                didReadRegularField = true
                regularFields.append(field)
            }
        }

        return HeaderBlock(statusCode: statusCode, fields: regularFields)
    }

    private func parseContentLength(_ fields: [(name: String, value: String)]) throws -> UInt64? {
        let values = fields.filter { $0.name == "content-length" }.map(\.value)
        guard !values.isEmpty else { return nil }

        var parsedValue: UInt64?
        for fieldValue in values {
            let components = fieldValue.split(separator: ",", omittingEmptySubsequences: false)
            for component in components {
                let digits = component.trimmingCharacters(in: .whitespaces)
                guard !digits.isEmpty,
                      digits.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                      let value = UInt64(digits) else {
                    throw PixivDirectConnectionError.messageError
                }
                guard parsedValue == nil || parsedValue == value else {
                    throw PixivDirectConnectionError.messageError
                }
                parsedValue = value
            }
        }
        return parsedValue
    }

    private static let connectionSpecificFieldNames: Set<String> = [
        "connection",
        "keep-alive",
        "proxy-connection",
        "transfer-encoding",
        "upgrade"
    ]

    private static func isFieldNameCharacter(_ byte: UInt8) -> Bool {
        (byte >= 48 && byte <= 57) ||
            (byte >= 65 && byte <= 90) ||
            (byte >= 97 && byte <= 122) ||
            [33, 35, 36, 37, 38, 39, 42, 43, 45, 46, 94, 95, 96, 124, 126].contains(byte)
    }

    private static func isValidFieldValue(_ byte: UInt8) -> Bool {
        byte == 9 || (byte >= 32 && byte <= 126) || byte >= 128
    }

    private func decodeString(in data: Data, offset: inout Int, prefixBits: Int) throws -> String {
        guard offset < data.count else {
            throw PixivDirectConnectionError.qpackDecompressionFailed
        }
        let first = data[offset]
        let huffmanMask = UInt8(1 << prefixBits)
        let isHuffman = first & huffmanMask != 0
        guard let length = decodePrefixedInteger(in: data, offset: &offset, prefixBits: prefixBits),
              length <= UInt64(data.count - offset) else {
            throw PixivDirectConnectionError.qpackDecompressionFailed
        }
        let end = offset + Int(length)
        let valueData = data.subdata(in: offset..<end)
        offset = end
        let decodedData = if isHuffman {
            try PixivHPACKHuffmanDecoder.decode(valueData)
        } else {
            valueData
        }
        guard let string = String(data: decodedData, encoding: .utf8) else {
            throw PixivDirectConnectionError.qpackDecompressionFailed
        }
        return string
    }

    private func decodeInteger(in data: Data, offset: inout Int) -> UInt64? {
        guard offset < data.count else { return nil }
        let first = data[offset]
        let length = 1 << Int(first >> 6)
        guard data.count - offset >= length else { return nil }
        var value = UInt64(first & 0x3f)
        if length > 1 {
            for index in 1..<length {
                value = (value << 8) | UInt64(data[offset + index])
            }
        }
        offset += length
        return value
    }

    private func decodePrefixedInteger(in data: Data, offset: inout Int, prefixBits: Int) -> UInt64? {
        guard offset < data.count, prefixBits > 0, prefixBits <= 8 else { return nil }
        let first = data[offset]
        let mask = UInt8((1 << prefixBits) - 1)
        var value = UInt64(first & mask)
        offset += 1
        let limit = UInt64(mask)
        guard value == limit else { return value }

        var shift: UInt64 = 0
        while offset < data.count {
            let byte = data[offset]
            offset += 1
            if shift >= 63 {
                return nil
            }
            value += UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 {
                return value
            }
            shift += 7
        }
        return nil
    }

    private func staticEntry(index: UInt64) -> (name: String, value: String)? {
        PixivQPACKStaticTable.entry(index: index)
    }
}

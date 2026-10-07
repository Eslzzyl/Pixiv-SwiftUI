import Foundation
import Network
import Security

nonisolated final class PixivTCPHTTPSession: @unchecked Sendable {
    private enum BodyMode {
        case none
        case contentLength(Int64)
        case chunked
        case untilConnectionClose
    }

    private enum ChunkState {
        case size
        case data(Int64)
        case dataTerminator
        case trailers
    }

    private let request: URLRequest
    private let host: String
    private let address: String
    private let timeout: TimeInterval
    private let maxResponseBytes: Int?
    private let onResponse: (@Sendable (HTTPURLResponse) throws -> Void)?
    private let onBody: (@Sendable (Data) throws -> Void)?
    private let queue: DispatchQueue
    private let lock = NSLock()

    private var connection: NWConnection?
    private var continuation: CheckedContinuation<PixivDirectResponse, Error>?
    private var timeoutWorkItem: DispatchWorkItem?
    private var response: HTTPURLResponse?
    private var bodyMode: BodyMode?
    private var chunkState = ChunkState.size
    private var buffer = Data()
    private var body = Data()
    private var bodyByteCount: Int64 = 0
    private var isFinished = false

    init(
        request: URLRequest,
        host: String,
        address: String,
        timeout: TimeInterval,
        maxResponseBytes: Int?,
        onResponse: (@Sendable (HTTPURLResponse) throws -> Void)?,
        onBody: (@Sendable (Data) throws -> Void)?
    ) {
        self.request = request
        self.host = host
        self.address = address
        self.timeout = timeout
        self.maxResponseBytes = maxResponseBytes
        self.onResponse = onResponse
        self.onBody = onBody
        queue = DispatchQueue(label: "com.pixiv.tcp-fallback.\(address).\(UUID().uuidString)")
    }

    func run() async throws -> PixivDirectResponse {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PixivDirectResponse, Error>) in
                lock.lock()
                guard !isFinished else {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                lock.unlock()
                start()
            }
        } onCancel: {
            finish(.failure(CancellationError()))
        }
    }

    private func start() {
        guard let connection = makeConnection() else {
            finish(.failure(PixivDirectConnectionError.invalidRequest))
            return
        }

        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.finish(.failure(PixivDirectConnectionError.timedOut))
        }

        lock.lock()
        guard !isFinished else {
            lock.unlock()
            connection.cancel()
            return
        }
        self.connection = connection
        self.timeoutWorkItem = timeoutWorkItem
        lock.unlock()

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                self.receiveNext(from: connection)
                self.sendRequest(on: connection)
            case let .waiting(error):
                self.finish(.failure(PixivDirectConnectionError.fromTransportError(error)))
            case let .failed(error):
                self.finish(.failure(PixivDirectConnectionError.fromTransportError(error)))
            case .cancelled:
                self.lock.lock()
                let wasFinished = self.isFinished
                self.lock.unlock()
                if !wasFinished {
                    self.finish(.failure(CancellationError()))
                }
            default:
                break
            }
        }

        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
    }

    private func makeConnection() -> NWConnection? {
        guard let port = NWEndpoint.Port(rawValue: 443) else { return nil }

        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, host)
        sec_protocol_options_set_verify_block(
            tlsOptions.securityProtocolOptions,
            { [host] _, trustRef, completionHandler in
                let trust = sec_trust_copy_ref(trustRef).takeRetainedValue()
                let policy = SecPolicyCreateSSL(true, host as CFString)
                SecTrustSetPolicies(trust, policy)
                var error: CFError?
                completionHandler(SecTrustEvaluateWithError(trust, &error))
            },
            queue
        )

        let parameters = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        parameters.preferNoProxies = true
        return NWConnection(
            to: .hostPort(host: NWEndpoint.Host(address), port: port),
            using: parameters
        )
    }

    private func sendRequest(on connection: NWConnection) {
        do {
            let payload = try makeRequestPayload()
            connection.send(
                content: payload,
                contentContext: .defaultMessage,
                isComplete: true,
                completion: .contentProcessed { [weak self] error in
                    if let error {
                        self?.finish(.failure(PixivDirectConnectionError.fromTransportError(error)))
                    }
                }
            )
        } catch {
            finish(.failure(error))
        }
    }

    private func makeRequestPayload() throws -> Data {
        guard let url = request.url else {
            throw PixivDirectConnectionError.invalidRequest
        }

        let method = request.httpMethod?.uppercased() ?? "GET"
        let path = url.path(percentEncoded: true).isEmpty ? "/" : url.path(percentEncoded: true)
        let target: String
        if let query = url.query(percentEncoded: true), !query.isEmpty {
            target = "\(path)?\(query)"
        } else {
            target = path
        }

        let body = request.httpBody ?? Data()
        var headers: [String: String] = [:]
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            headers[key.lowercased()] = value
        }
        headers.removeValue(forKey: "host")
        headers.removeValue(forKey: "connection")
        headers.removeValue(forKey: "keep-alive")
        headers.removeValue(forKey: "proxy-connection")
        headers.removeValue(forKey: "transfer-encoding")
        let port = url.port ?? 443
        headers["host"] = port == 443 ? host : "\(host):\(port)"
        headers["connection"] = "close"
        headers["accept-encoding"] = "identity"
        if headers["user-agent"] == nil {
            headers["user-agent"] = "PixivIOSApp/7.13.3 (iOS 14.6; iPhone13,2)"
        }
        if body.isEmpty {
            headers.removeValue(forKey: "content-length")
        } else {
            headers["content-length"] = String(body.count)
        }

        var payload = Data("\(method) \(target) HTTP/1.1\r\n".utf8)
        for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
            payload.append(Data("\(key): \(value)\r\n".utf8))
        }
        payload.append(Data("\r\n".utf8))
        payload.append(body)

        guard payload.count <= 32 * 1024 * 1024 else {
            throw PixivDirectConnectionError.requestTooLarge
        }
        return payload
    }

    private func receiveNext(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }
            do {
                if let data, !data.isEmpty {
                    self.buffer.append(data)
                    try self.processBuffer()
                }

                self.lock.lock()
                let finished = self.isFinished
                self.lock.unlock()
                guard !finished else { return }

                if let error {
                    self.finish(.failure(PixivDirectConnectionError.fromTransportError(error)))
                } else if isComplete {
                    try self.finishAtConnectionClose()
                } else {
                    self.receiveNext(from: connection)
                }
            } catch {
                self.finish(.failure(error))
            }
        }
    }

    private func processBuffer() throws {
        if response == nil {
            guard let headerRange = buffer.range(of: Data([13, 10, 13, 10])) else {
                return
            }
            let headerData = Data(buffer[..<headerRange.lowerBound])
            buffer.removeSubrange(0..<headerRange.upperBound)
            try processHeaders(headerData)
        }

        guard let bodyMode else { return }
        switch bodyMode {
        case .none:
            finish(.success(makeResult()))
        case let .contentLength(expectedLength):
            let remaining = expectedLength - bodyByteCount
            if remaining > 0, !buffer.isEmpty {
                let count = min(Int(remaining), buffer.count)
                let data = Data(buffer.prefix(count))
                buffer.removeSubrange(0..<count)
                try deliver(data)
            }
            if bodyByteCount == expectedLength {
                finish(.success(makeResult()))
            }
        case .chunked:
            try processChunkedBody()
        case .untilConnectionClose:
            if !buffer.isEmpty {
                let data = buffer
                buffer.removeAll(keepingCapacity: true)
                try deliver(data)
            }
        }
    }

    private func processHeaders(_ data: Data) throws {
        guard let headerString = String(data: data, encoding: .utf8) else {
            throw PixivDirectConnectionError.invalidResponse
        }
        let lines = headerString.components(separatedBy: "\r\n")
        guard let statusLine = lines.first else {
            throw PixivDirectConnectionError.messageError
        }
        let statusParts = statusLine.split(separator: " ", maxSplits: 2)
        guard statusParts.count >= 2, let statusCode = Int(statusParts[1]) else {
            throw PixivDirectConnectionError.messageError
        }

        var headerFields: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            guard let separator = line.firstIndex(of: ":") else {
                throw PixivDirectConnectionError.messageError
            }
            let name = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                throw PixivDirectConnectionError.messageError
            }
            headerFields[name] = value
        }

        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: statusCode,
                  httpVersion: "HTTP/1.1",
                  headerFields: headerFields
              ) else {
            throw PixivDirectConnectionError.invalidResponse
        }
        self.response = response
        do {
            try onResponse?(response)
        } catch {
            throw PixivDirectResponseCallbackError(error)
        }

        let method = request.httpMethod?.uppercased() ?? "GET"
        if method == "HEAD" || (100..<200).contains(statusCode) || statusCode == 204 || statusCode == 304 {
            bodyMode = BodyMode.none
        } else if headerFields["transfer-encoding"]?
            .split(separator: ",")
            .contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("chunked") == .orderedSame }) == true {
            bodyMode = .chunked
        } else if let contentLength = headerFields["content-length"].flatMap(Int64.init), contentLength >= 0 {
            bodyMode = .contentLength(contentLength)
        } else {
            bodyMode = .untilConnectionClose
        }
    }

    private func processChunkedBody() throws {
        while true {
            switch chunkState {
            case .size:
                guard let line = readLine() else { return }
                let sizeText = line.split(separator: ";", maxSplits: 1).first ?? ""
                guard let size = Int64(sizeText.trimmingCharacters(in: .whitespacesAndNewlines), radix: 16) else {
                    throw PixivDirectConnectionError.messageError
                }
                chunkState = size == 0 ? .trailers : .data(size)
            case let .data(remaining):
                guard remaining > 0 else {
                    chunkState = .dataTerminator
                    continue
                }
                guard !buffer.isEmpty else { return }
                let count = min(Int(remaining), buffer.count)
                let data = Data(buffer.prefix(count))
                buffer.removeSubrange(0..<count)
                try deliver(data)
                chunkState = .data(remaining - Int64(count))
            case .dataTerminator:
                guard buffer.count >= 2 else { return }
                guard buffer.prefix(2) == Data([13, 10]) else {
                    throw PixivDirectConnectionError.messageError
                }
                buffer.removeSubrange(0..<2)
                chunkState = .size
            case .trailers:
                guard let line = readLine() else { return }
                if line.isEmpty {
                    finish(.success(makeResult()))
                    return
                }
            }
        }
    }

    private func readLine() -> String? {
        guard let range = buffer.range(of: Data([13, 10])) else { return nil }
        let line = String(data: buffer[..<range.lowerBound], encoding: .utf8)
        buffer.removeSubrange(0..<range.upperBound)
        return line
    }

    private func deliver(_ data: Data) throws {
        guard !data.isEmpty else { return }
        let (nextCount, overflow) = bodyByteCount.addingReportingOverflow(Int64(data.count))
        guard !overflow else {
            throw PixivDirectConnectionError.responseTooLarge
        }
        if let maxResponseBytes, nextCount > Int64(maxResponseBytes) {
            throw PixivDirectConnectionError.responseTooLarge
        }
        if let onBody {
            do {
                try onBody(data)
            } catch {
                throw PixivDirectResponseCallbackError(error)
            }
        } else {
            body.append(data)
        }
        bodyByteCount = nextCount
    }

    private func finishAtConnectionClose() throws {
        guard response != nil,
              let bodyMode else {
            throw PixivDirectConnectionError.invalidResponse
        }
        switch bodyMode {
        case .untilConnectionClose:
            finish(.success(makeResult()))
        case .none:
            finish(.success(makeResult()))
        case let .contentLength(expectedLength) where bodyByteCount == expectedLength:
            finish(.success(makeResult()))
        default:
            throw PixivDirectConnectionError.incompleteResponse
        }
    }

    private func makeResult() -> PixivDirectResponse {
        guard let response else {
            preconditionFailure("TCP response is unavailable")
        }
        return PixivDirectResponse(
            data: body,
            response: response,
            negotiatedProtocol: "http/1.1",
            bodyByteCount: bodyByteCount
        )
    }

    private func finish(_ result: Result<PixivDirectResponse, Error>) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        let continuation = self.continuation
        let timeoutWorkItem = self.timeoutWorkItem
        let connection = self.connection
        self.continuation = nil
        lock.unlock()

        timeoutWorkItem?.cancel()
        connection?.cancel()
        continuation?.resume(with: result)
    }
}

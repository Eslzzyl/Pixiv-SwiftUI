import Foundation
import Network
import Security
import os.log

nonisolated struct PixivHTTP3ConnectionKey: Hashable, Sendable {
    let scheme: String
    let host: String
    let port: UInt16
    let address: String
    let tlsServerName: String
    let tlsConfiguration = "system-trust;alpn-h3"
}

actor PixivHTTP3ConnectionPool {
    private struct Entry {
        let connection: PixivHTTP3PooledConnection
        var activeLeases: Int
        var lastUsed: Date
    }

    private var entries: [PixivHTTP3ConnectionKey: Entry] = [:]
    private let idleLifetime: TimeInterval = 60
    private let maximumEntries = 16

    func connection(
        for key: PixivHTTP3ConnectionKey,
        host: String,
        address: String
    ) -> PixivHTTP3PooledConnection {
        evictExpiredEntries()

        if var entry = entries[key], entry.connection.acceptsRequests {
            entry.activeLeases += 1
            entry.lastUsed = Date()
            entries[key] = entry
            Logger.network.info(
                "HTTP/3 connection pool reused host=\(host, privacy: .public) endpoint=\(address, privacy: .public)"
            )
            return entry.connection
        }

        if let stale = entries.removeValue(forKey: key) {
            stale.connection.close()
        }

        let connection = PixivHTTP3PooledConnection(key: key) { [weak self] retiredConnection in
            Task {
                await self?.retire(key, connection: retiredConnection)
            }
        }
        entries[key] = Entry(connection: connection, activeLeases: 1, lastUsed: Date())
        connection.start()
        evictOverflowEntries()
        Logger.network.info(
            "HTTP/3 connection pool created host=\(host, privacy: .public) endpoint=\(address, privacy: .public)"
        )
        return connection
    }

    func release(_ connection: PixivHTTP3PooledConnection, for key: PixivHTTP3ConnectionKey) {
        guard var entry = entries[key], entry.connection === connection else {
            connection.closeWhenIdle()
            return
        }

        entry.activeLeases = max(0, entry.activeLeases - 1)
        entry.lastUsed = Date()
        if connection.acceptsRequests {
            entries[key] = entry
        } else {
            entries.removeValue(forKey: key)
            connection.closeWhenIdle()
        }
    }

    func closeAll() {
        let connections = entries.values.map(\.connection)
        entries.removeAll()
        connections.forEach { $0.close() }
    }

    private func retire(_ key: PixivHTTP3ConnectionKey, connection: PixivHTTP3PooledConnection) {
        guard let entry = entries[key], entry.connection === connection else { return }
        entries.removeValue(forKey: key)
        connection.closeWhenIdle()
    }

    private func evictExpiredEntries() {
        let now = Date()
        let expiredKeys = entries.compactMap { key, entry in
            entry.activeLeases == 0 && now.timeIntervalSince(entry.lastUsed) >= idleLifetime ? key : nil
        }
        for key in expiredKeys {
            entries.removeValue(forKey: key)?.connection.close()
        }
    }

    private func evictOverflowEntries() {
        while entries.count > maximumEntries {
            guard let candidate = entries
                .filter({ $0.value.activeLeases == 0 })
                .min(by: { $0.value.lastUsed < $1.value.lastUsed }) else {
                return
            }
            entries.removeValue(forKey: candidate.key)?.connection.close()
        }
    }
}

nonisolated final class PixivHTTP3PooledConnection: @unchecked Sendable {
    let queue: DispatchQueue

    private let key: PixivHTTP3ConnectionKey
    private let lock = NSLock()
    private let onRetire: @Sendable (PixivHTTP3PooledConnection) -> Void
    private var group: NWConnectionGroup?
    private var clientControlStream: NWConnection?
    private var incomingStreams: [UUID: PixivHTTP3IncomingStream] = [:]
    private var controlParser: PixivHTTP3ControlStreamParser?
    private var qpackDecoderStreamParser = PixivHTTP3QPACKDecoderStreamParser()
    private var readinessWaiters: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var receivedSettings = false
    private var sentClientSettings = false
    private var sawServerControlStream = false
    private var sawServerEncoderStream = false
    private var sawServerDecoderStream = false
    private var activeRequestStreams = 0
    private var isDraining = false
    private var isClosed = false
    private var terminalError: Error?

    init(
        key: PixivHTTP3ConnectionKey,
        onRetire: @escaping @Sendable (PixivHTTP3PooledConnection) -> Void
    ) {
        self.key = key
        self.onRetire = onRetire
        self.queue = DispatchQueue(label: "com.pixiv.http3.pool.\(key.address).\(UUID().uuidString)")
    }

    var acceptsRequests: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !isDraining && !isClosed && terminalError == nil
    }

    func start() {
        guard let group = makeGroup() else {
            failConnection(PixivDirectConnectionError.invalidRequest)
            return
        }

        group.newConnectionHandler = { [weak self] connection in
            self?.handleIncomingConnection(connection)
        }
        group.stateUpdateHandler = { [weak self] state in
            self?.handleGroupState(state)
        }

        lock.lock()
        guard !isClosed else {
            lock.unlock()
            group.cancel()
            return
        }
        self.group = group
        group.start(queue: queue)
        lock.unlock()
    }

    func waitForSettings() async throws {
        try Task.checkCancellation()
        let waiterID = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.lock()
                if receivedSettings {
                    lock.unlock()
                    continuation.resume()
                    return
                }
                if let terminalError {
                    lock.unlock()
                    continuation.resume(throwing: terminalError)
                    return
                }
                if isDraining || isClosed {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                readinessWaiters[waiterID] = continuation
                lock.unlock()
            }
        } onCancel: {
            cancelReadinessWaiter(waiterID)
        }
        try Task.checkCancellation()
    }

    func makeRequestStream() throws -> NWConnection {
        lock.lock()
        guard receivedSettings,
              !isDraining,
              !isClosed,
              terminalError == nil,
              let group else {
            let error = terminalError ?? PixivDirectConnectionError.transportFailure(
                "HTTP/3 connection is not accepting request streams",
                isRetryable: true
            )
            lock.unlock()
            throw error
        }
        activeRequestStreams += 1
        lock.unlock()

        guard let request = NWConnection(from: group) else {
            releaseRequestStream()
            throw PixivDirectConnectionError.transportFailure(
                "Unable to create HTTP/3 request stream",
                isRetryable: true
            )
        }

        lock.lock()
        let shouldCancel = isDraining || isClosed || terminalError != nil
        lock.unlock()
        if shouldCancel {
            request.cancel()
            releaseRequestStream()
            throw PixivDirectConnectionError.transportFailure(
                "HTTP/3 connection entered shutdown",
                isRetryable: true
            )
        }
        return request
    }

    func releaseRequestStream() {
        lock.lock()
        activeRequestStreams = max(0, activeRequestStreams - 1)
        let shouldClose = (isDraining || isClosed || terminalError != nil) && activeRequestStreams == 0
        let group = shouldClose ? self.group : nil
        if shouldClose {
            isClosed = true
        }
        lock.unlock()
        group?.cancel()
    }

    func closeWhenIdle() {
        lock.lock()
        isDraining = true
        let shouldClose = activeRequestStreams == 0 && !isClosed
        let group = shouldClose ? self.group : nil
        if shouldClose {
            isClosed = true
        }
        lock.unlock()
        group?.cancel()
    }

    func close() {
        lock.lock()
        guard !isClosed else {
            lock.unlock()
            return
        }
        isClosed = true
        isDraining = true
        terminalError = CancellationError()
        let group = self.group
        let waiters = Array(readinessWaiters.values)
        readinessWaiters.removeAll()
        lock.unlock()

        waiters.forEach { $0.resume(throwing: CancellationError()) }
        group?.cancel()
    }

    private func makeGroup() -> NWConnectionGroup? {
        guard let port = NWEndpoint.Port(rawValue: key.port) else { return nil }

        let options = NWProtocolQUIC.Options(alpn: ["h3"])
        options.direction = .bidirectional
        options.initialMaxData = 8 * 1024 * 1024
        options.initialMaxStreamsBidirectional = 16
        options.initialMaxStreamsUnidirectional = 16
        options.initialMaxStreamDataBidirectionalLocal = 2 * 1024 * 1024
        options.initialMaxStreamDataBidirectionalRemote = 2 * 1024 * 1024
        options.initialMaxStreamDataUnidirectional = 2 * 1024 * 1024
        options.idleTimeout = 120_000

        let serverName = key.tlsServerName
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

        return NWConnectionGroup(
            with: NWMultiplexGroup(
                to: .hostPort(host: NWEndpoint.Host(key.address), port: port)
            ),
            using: parameters
        )
    }

    private func handleGroupState(_ state: NWConnectionGroup.State) {
        Logger.network.info("HTTP/3 pooled transport state=\(String(describing: state), privacy: .public)")
        switch state {
        case .ready:
            Logger.network.info("HTTP/3 pooled transport ready endpoint=\(self.key.address, privacy: .public)")
            startClientControlStream()
        case let .failed(error):
            failConnection(PixivDirectConnectionError.fromTransportError(error))
        case .cancelled:
            lock.lock()
            let wasClosed = isClosed
            lock.unlock()
            if !wasClosed {
                failConnection(CancellationError())
            }
        case .setup, .waiting:
            break
        @unknown default:
            break
        }
    }

    private func startClientControlStream() {
        lock.lock()
        guard !isClosed, clientControlStream == nil, let group else {
            lock.unlock()
            return
        }
        lock.unlock()

        let options = NWProtocolQUIC.Options()
        options.direction = .unidirectional
        guard let control = NWConnection(from: group, using: options) else {
            failConnection(PixivDirectConnectionError.transportFailure(
                "Unable to create HTTP/3 control stream",
                isRetryable: true
            ))
            return
        }

        control.stateUpdateHandler = { [weak self, weak control] state in
            guard let self, let control else { return }
            switch state {
            case .ready:
                self.sendClientSettings(on: control)
            case let .failed(error):
                self.failConnection(PixivDirectConnectionError.fromTransportError(error))
            case .cancelled:
                self.lock.lock()
                let wasClosed = self.isClosed
                self.lock.unlock()
                if !wasClosed {
                    self.failConnection(PixivDirectConnectionError.closedCriticalStream)
                }
            default:
                break
            }
        }

        lock.lock()
        guard !isClosed, clientControlStream == nil else {
            lock.unlock()
            control.cancel()
            return
        }
        clientControlStream = control
        lock.unlock()
        control.start(queue: queue)
    }

    private func sendClientSettings(on control: NWConnection) {
        lock.lock()
        guard !sentClientSettings, !isClosed else {
            lock.unlock()
            return
        }
        sentClientSettings = true
        lock.unlock()

        var settings = Data()
        settings.append(PixivHTTP3Frame.encodeInteger(0x01))
        settings.append(PixivHTTP3Frame.encodeInteger(0))
        settings.append(PixivHTTP3Frame.encodeInteger(0x07))
        settings.append(PixivHTTP3Frame.encodeInteger(0))

        var payload = Data([0x00])
        payload.append(PixivHTTP3Frame.make(type: 0x04, payload: settings))
        control.send(
            content: payload,
            contentContext: .defaultMessage,
            isComplete: false,
            completion: .contentProcessed { [weak self] error in
                if let error {
                    self?.failConnection(PixivDirectConnectionError.fromTransportError(error))
                }
            }
        )
    }

    private func handleIncomingConnection(_ connection: NWConnection) {
        Logger.network.info("HTTP/3 peer unidirectional stream accepted endpoint=\(self.key.address, privacy: .public)")
        let identifier = UUID()
        let stream = PixivHTTP3IncomingStream(
            connection: connection,
            queue: queue,
            onEvent: { [weak self] type, data, isComplete, errorDescription, isFirst, pushID in
                self?.handleIncomingStream(
                    type: type,
                    data: data,
                    isComplete: isComplete,
                    errorDescription: errorDescription,
                    isFirst: isFirst,
                    pushID: pushID
                )
            },
            onFinished: { [weak self] in
                self?.removeIncomingStream(identifier)
            }
        )
        lock.lock()
        incomingStreams[identifier] = stream
        lock.unlock()
        stream.start()
    }

    private func removeIncomingStream(_ identifier: UUID) {
        lock.lock()
        incomingStreams.removeValue(forKey: identifier)
        lock.unlock()
    }

    private func handleIncomingStream(
        type: UInt64,
        data: Data,
        isComplete: Bool,
        errorDescription: String?,
        isFirst: Bool,
        pushID: UInt64?
    ) {
        if isFirst {
            Logger.network.info("HTTP/3 peer stream type=\(type) endpoint=\(self.key.address, privacy: .public)")
        }
        if isFirst, !registerIncomingStream(type, pushID: pushID) {
            return
        }

        if let errorDescription {
            Logger.network.debug(
                "HTTP/3 peer unidirectional stream ended type=\(type) error=\(errorDescription, privacy: .public)"
            )
        }

        switch type {
        case 0x00:
            guard data.isEmpty || processControlData(data) else { return }
            if isComplete || errorDescription != nil {
                failConnection(PixivDirectConnectionError.closedCriticalStream)
            }
        case 0x02:
            if !data.isEmpty {
                let error = PixivDirectConnectionError.qpackEncoderStreamError
                failConnection(error, connectionErrorCode: error.quicConnectionErrorCode)
                return
            }
            if isComplete || errorDescription != nil {
                failConnection(PixivDirectConnectionError.closedCriticalStream)
            }
        case 0x03:
            guard data.isEmpty || processQPACKDecoderData(data) else { return }
            if isComplete || errorDescription != nil {
                failConnection(PixivDirectConnectionError.closedCriticalStream)
            }
        case 0x01:
            if pushID != nil {
                failConnection(PixivDirectConnectionError.idError)
            }
        default:
            break
        }
    }

    private func registerIncomingStream(_ type: UInt64, pushID: UInt64?) -> Bool {
        lock.lock()
        let isDuplicate: Bool
        switch type {
        case 0x00:
            isDuplicate = sawServerControlStream
            sawServerControlStream = true
            if !isDuplicate {
                controlParser = PixivHTTP3ControlStreamParser()
            }
        case 0x02:
            isDuplicate = sawServerEncoderStream
            sawServerEncoderStream = true
        case 0x03:
            isDuplicate = sawServerDecoderStream
            sawServerDecoderStream = true
        default:
            isDuplicate = false
        }
        lock.unlock()

        if isDuplicate {
            failConnection(PixivDirectConnectionError.streamCreationError)
            return false
        }
        if type == 0x01, pushID != nil {
            failConnection(PixivDirectConnectionError.idError)
            return false
        }
        return true
    }

    private func processControlData(_ data: Data) -> Bool {
        do {
            lock.lock()
            let parser = controlParser
            lock.unlock()
            guard let parser else {
                throw PixivDirectConnectionError.missingSettings
            }
            for event in try parser.append(data) {
                switch event {
                case .settings:
                    markSettingsReceived()
                case .goAway:
                    beginDraining()
                }
            }
            return true
        } catch {
            let directError = error as? PixivDirectConnectionError
            failConnection(error, connectionErrorCode: directError?.quicConnectionErrorCode)
            return false
        }
    }

    private func processQPACKDecoderData(_ data: Data) -> Bool {
        do {
            try qpackDecoderStreamParser.append(data)
            return true
        } catch {
            let directError = error as? PixivDirectConnectionError
            failConnection(error, connectionErrorCode: directError?.quicConnectionErrorCode)
            return false
        }
    }

    private func markSettingsReceived() {
        lock.lock()
        guard !receivedSettings, !isClosed, terminalError == nil else {
            lock.unlock()
            return
        }
        receivedSettings = true
        let address = key.address
        let waiters = Array(readinessWaiters.values)
        readinessWaiters.removeAll()
        lock.unlock()
        Logger.network.info("HTTP/3 peer SETTINGS accepted endpoint=\(address, privacy: .public)")
        waiters.forEach { $0.resume() }
    }

    private func beginDraining() {
        lock.lock()
        guard !isDraining, !isClosed else {
            lock.unlock()
            return
        }
        isDraining = true
        let shouldClose = activeRequestStreams == 0
        let group = shouldClose ? self.group : nil
        if shouldClose {
            isClosed = true
        }
        lock.unlock()

        onRetire(self)
        group?.cancel()
    }

    private func failConnection(_ error: Error, connectionErrorCode: UInt64? = nil) {
        lock.lock()
        guard !isClosed else {
            lock.unlock()
            return
        }
        isClosed = true
        isDraining = true
        terminalError = error
        let group = self.group
        let control = clientControlStream
        let waiters = Array(readinessWaiters.values)
        readinessWaiters.removeAll()
        lock.unlock()

        if let connectionErrorCode,
           let metadata = control?.metadata(definition: NWProtocolQUIC.definition) as? NWProtocolQUIC.Metadata {
            metadata.applicationError = NWProtocolQUIC.ApplicationError(code: connectionErrorCode, reason: nil)
        }
        waiters.forEach { $0.resume(throwing: error) }
        onRetire(self)
        group?.cancel()
    }

    private func cancelReadinessWaiter(_ waiterID: UUID) {
        lock.lock()
        let continuation = readinessWaiters.removeValue(forKey: waiterID)
        lock.unlock()
        continuation?.resume(throwing: CancellationError())
    }
}

nonisolated private final class PixivHTTP3IncomingStream: @unchecked Sendable {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let onEvent: @Sendable (UInt64, Data, Bool, String?, Bool, UInt64?) -> Void
    private let onFinished: @Sendable () -> Void
    private var buffer = Data()
    private var streamType: UInt64?
    private var pushID: UInt64?
    private var didReadPushID = false
    private var didFinish = false

    init(
        connection: NWConnection,
        queue: DispatchQueue,
        onEvent: @escaping @Sendable (UInt64, Data, Bool, String?, Bool, UInt64?) -> Void,
        onFinished: @escaping @Sendable () -> Void
    ) {
        self.connection = connection
        self.queue = queue
        self.onEvent = onEvent
        self.onFinished = onFinished
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .ready = state {
                self.receiveNext()
            }
        }
        connection.start(queue: queue)
    }

    private func receiveNext() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffer.append(data)
            }

            if self.streamType == nil {
                var offset = 0
                guard let type = PixivHTTP3VariableInteger.decode(in: self.buffer, offset: &offset) else {
                    if isComplete || error != nil {
                        self.finish()
                        return
                    }
                    self.receiveNext()
                    return
                }
                self.streamType = type
                self.buffer.removeSubrange(0..<offset)
            }

            if self.streamType == 0x01, !self.didReadPushID {
                var offset = 0
                guard let pushID = PixivHTTP3VariableInteger.decode(in: self.buffer, offset: &offset) else {
                    if isComplete || error != nil {
                        self.finish()
                        return
                    }
                    self.receiveNext()
                    return
                }
                self.pushID = pushID
                self.didReadPushID = true
                self.buffer.removeSubrange(0..<offset)
            }

            guard let streamType = self.streamType else { return }
            let content = self.buffer
            self.buffer.removeAll(keepingCapacity: true)
            self.onEvent(
                streamType,
                content,
                isComplete,
                error?.localizedDescription,
                !self.didDispatchType,
                self.pushID
            )
            self.didDispatchType = true

            if isComplete || error != nil {
                self.finish()
            } else {
                self.receiveNext()
            }
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onFinished()
    }

    private var didDispatchType = false
}

nonisolated private final class PixivHTTP3ControlStreamParser: @unchecked Sendable {
    enum Event {
        case settings
        case goAway
    }

    private var buffer = Data()
    private var receivedSettings = false
    private var lastGoAwayID: UInt64?

    func append(_ data: Data) throws -> [Event] {
        buffer.append(data)
        guard buffer.count <= 64 * 1024 else {
            throw PixivDirectConnectionError.settingsError
        }

        var events: [Event] = []
        var offset = 0
        while offset < buffer.count {
            let frameStart = offset
            guard let frameType = PixivHTTP3VariableInteger.decode(in: buffer, offset: &offset),
                  let length = PixivHTTP3VariableInteger.decode(in: buffer, offset: &offset),
                  length <= 64 * 1024,
                  length <= UInt64(buffer.count - offset) else {
                offset = frameStart
                break
            }

            let frameLength = Int(length)
            let frameEnd = offset + frameLength
            let payload = buffer.subdata(in: offset..<frameEnd)
            try process(frameType: frameType, payload: payload, events: &events)
            offset = frameEnd
        }

        if offset > 0 {
            buffer.removeSubrange(0..<offset)
        }
        return events
    }

    private func process(frameType: UInt64, payload: Data, events: inout [Event]) throws {
        if !receivedSettings {
            guard frameType == 0x04 else {
                throw PixivDirectConnectionError.missingSettings
            }
            try validateSettings(payload)
            receivedSettings = true
            events.append(.settings)
            return
        }

        switch frameType {
        case 0x04, 0x00, 0x01, 0x05, 0x0d:
            throw PixivDirectConnectionError.frameUnexpected
        case 0x03:
            throw PixivDirectConnectionError.idError
        case 0x07:
            var offset = 0
            guard let identifier = PixivHTTP3VariableInteger.decode(in: payload, offset: &offset),
                  offset == payload.count,
                  identifier & 0x03 == 0 else {
                throw PixivDirectConnectionError.idError
            }
            if let lastGoAwayID, identifier > lastGoAwayID {
                throw PixivDirectConnectionError.idError
            }
            lastGoAwayID = identifier
            events.append(.goAway)
        default:
            break
        }
    }

    private func validateSettings(_ payload: Data) throws {
        var offset = 0
        var identifiers = Set<UInt64>()
        while offset < payload.count {
            guard let identifier = PixivHTTP3VariableInteger.decode(in: payload, offset: &offset),
                  let value = PixivHTTP3VariableInteger.decode(in: payload, offset: &offset) else {
                throw PixivDirectConnectionError.settingsError
            }
            guard identifiers.insert(identifier).inserted else {
                throw PixivDirectConnectionError.settingsError
            }
            if [0x00, 0x02, 0x03, 0x04, 0x05].contains(identifier) {
                throw PixivDirectConnectionError.settingsError
            }
            _ = value
        }
    }
}

nonisolated private final class PixivHTTP3QPACKDecoderStreamParser: @unchecked Sendable {
    private var buffer = Data()

    func append(_ data: Data) throws {
        buffer.append(data)
        var offset = 0

        while offset < buffer.count {
            guard buffer[offset] & 0xc0 == 0x40 else {
                throw PixivDirectConnectionError.qpackDecoderStreamError
            }
            guard let instruction = try Self.decodeStreamCancellation(in: buffer, offset: offset) else {
                break
            }
            offset = instruction.endOffset
        }

        if offset > 0 {
            buffer.removeSubrange(0..<offset)
        }
    }

    private static func decodeStreamCancellation(
        in data: Data,
        offset: Int
    ) throws -> (streamID: UInt64, endOffset: Int)? {
        let prefixMaximum = UInt64(0x3f)
        let maximumStreamID = (UInt64(1) << 62) - 1
        var value = UInt64(data[offset] & 0x3f)
        var cursor = offset + 1

        guard value == prefixMaximum else {
            return (value, cursor)
        }

        var shift = 0
        while cursor < data.count {
            let byte = data[cursor]
            cursor += 1
            let payload = UInt64(byte & 0x7f)

            guard shift < 62,
                  payload <= (maximumStreamID - value) >> shift else {
                throw PixivDirectConnectionError.qpackDecoderStreamError
            }
            value += payload << shift

            if byte & 0x80 == 0 {
                return (value, cursor)
            }
            shift += 7
        }

        return nil
    }
}

nonisolated enum PixivHTTP3VariableInteger {
    static func decode(in data: Data, offset: inout Int) -> UInt64? {
        guard offset < data.count else { return nil }
        let first = data[offset]
        let encodedLength = 1 << Int(first >> 6)
        guard data.count - offset >= encodedLength else { return nil }

        var value = UInt64(first & 0x3f)
        if encodedLength > 1 {
            for index in 1..<encodedLength {
                value = (value << 8) | UInt64(data[offset + index])
            }
        }
        offset += encodedLength
        return value
    }
}

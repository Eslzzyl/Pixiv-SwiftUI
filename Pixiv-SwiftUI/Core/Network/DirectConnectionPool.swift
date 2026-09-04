import Foundation
import Network

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
nonisolated struct DirectConnectionKey: Hashable, Sendable {
    let ip: String
    let port: Int
    let host: String
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
nonisolated final class ReusableDirectConnection: @unchecked Sendable {
    let connection: NWConnection
    let queue: DispatchQueue

    init(connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
    }

    var isReady: Bool {
        if case .ready = connection.state {
            return true
        }
        return false
    }

    func close() {
        connection.cancel()
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
actor DirectConnectionPool {
    static let shared = DirectConnectionPool()

    private struct IdleConnection {
        let connection: ReusableDirectConnection
        let lastUsedAt: Date
    }

    private var idleConnections: [DirectConnectionKey: [IdleConnection]] = [:]
    private var idleConnectionCount = 0
    private var cleanupTask: Task<Void, Never>?
    private let maxIdleConnections = 8
    private let maxIdleConnectionsPerKey = 2
    private let idleTimeout: TimeInterval = 30

    func checkout(for key: DirectConnectionKey) -> ReusableDirectConnection? {
        guard var connections = idleConnections[key] else { return nil }

        while let idleConnection = connections.popLast() {
            idleConnectionCount -= 1
            let isExpired = Date().timeIntervalSince(idleConnection.lastUsedAt) > idleTimeout
            guard !isExpired, idleConnection.connection.isReady else {
                idleConnection.connection.close()
                continue
            }

            idleConnections[key] = connections.isEmpty ? nil : connections
            stopCleanupTaskIfNeeded()
            return idleConnection.connection
        }

        idleConnections[key] = connections.isEmpty ? nil : connections
        stopCleanupTaskIfNeeded()
        return nil
    }

    func checkin(_ connection: ReusableDirectConnection, for key: DirectConnectionKey) {
        guard connection.isReady else {
            connection.close()
            return
        }

        var connections = idleConnections[key, default: []]
        guard connections.count < maxIdleConnectionsPerKey,
              idleConnectionCount < maxIdleConnections else {
            connection.close()
            return
        }

        connections.append(IdleConnection(connection: connection, lastUsedAt: Date()))
        idleConnections[key] = connections
        idleConnectionCount += 1
        startCleanupTaskIfNeeded()
    }

    func removeAll() {
        for connections in idleConnections.values {
            for idleConnection in connections {
                idleConnection.connection.close()
            }
        }
        idleConnections.removeAll()
        idleConnectionCount = 0
        cleanupTask?.cancel()
        cleanupTask = nil
    }

    private func startCleanupTaskIfNeeded() {
        guard cleanupTask == nil else { return }

        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(self?.idleTimeout ?? 30) * 1_000_000_000)
                } catch {
                    return
                }
                await self?.removeExpiredConnections()
            }
        }
    }

    private func stopCleanupTaskIfNeeded() {
        guard idleConnectionCount == 0 else { return }
        cleanupTask?.cancel()
        cleanupTask = nil
    }

    private func removeExpiredConnections() {
        let now = Date()
        let keys = Array(idleConnections.keys)

        for key in keys {
            guard let connections = idleConnections[key] else { continue }
            var retainedConnections: [IdleConnection] = []

            for idleConnection in connections {
                let isExpired = now.timeIntervalSince(idleConnection.lastUsedAt) > idleTimeout
                guard !isExpired, idleConnection.connection.isReady else {
                    idleConnection.connection.close()
                    idleConnectionCount -= 1
                    continue
                }
                retainedConnections.append(idleConnection)
            }

            if retainedConnections.isEmpty {
                idleConnections.removeValue(forKey: key)
            } else {
                idleConnections[key] = retainedConnections
            }
        }

        stopCleanupTaskIfNeeded()
    }
}

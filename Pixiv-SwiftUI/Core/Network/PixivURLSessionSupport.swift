import Foundation
import os.log

actor PixivDirectTCPFallbackPolicy {
    private var tcpPreferredUntil: [String: Date] = [:]
    private let cooldownDuration: TimeInterval = 60

    func prefersTCP(for origin: String) -> Bool {
        guard let expiration = tcpPreferredUntil[origin] else { return false }
        guard expiration > Date() else {
            tcpPreferredUntil.removeValue(forKey: origin)
            return false
        }
        return true
    }

    func recordTCPSuccess(for origin: String) {
        tcpPreferredUntil[origin] = Date().addingTimeInterval(cooldownDuration)
    }

    func reset() {
        tcpPreferredUntil.removeAll()
    }
}

final class PixivURLSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        guard let host = task.originalRequest?.url?.host else { return }

        let protocols = metrics.transactionMetrics.compactMap(\.networkProtocolName)
        let protocolDescription = protocols.isEmpty ? "unavailable" : protocols.joined(separator: ",")
        let statusCode = (task.response as? HTTPURLResponse)?.statusCode ?? -1
        let didUseHTTP3 = protocols.contains("h3")
        let didUseProxy = metrics.transactionMetrics.contains(where: \.isProxyConnection)
        Logger.network.debug(
            "URLSession metrics host=\(host, privacy: .public) status=\(statusCode) protocols=\(protocolDescription, privacy: .public) h3=\(didUseHTTP3) proxy=\(didUseProxy)"
        )
    }
}

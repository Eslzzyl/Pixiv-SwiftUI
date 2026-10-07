import Foundation
import os.log

actor PixivDirectTCPFallbackPolicy {
    private struct State {
        var consecutiveH3Failures = 0
        var tcpPreferredUntil: Date?
    }

    private var states: [String: State] = [:]
    private let h3FailureThreshold = 2
    private let cooldownDuration: TimeInterval = 30

    func prefersTCP(for origin: String) -> Bool {
        guard var state = states[origin],
              let expiration = state.tcpPreferredUntil else {
            return false
        }
        guard expiration > Date() else {
            state.tcpPreferredUntil = nil
            states[origin] = state
            return false
        }
        return true
    }

    func recordH3Failure(for origin: String) {
        var state = states[origin, default: State()]
        state.consecutiveH3Failures = min(state.consecutiveH3Failures + 1, h3FailureThreshold)
        states[origin] = state
    }

    func recordH3Success(for origin: String) {
        states[origin] = State()
    }

    func recordTCPSuccess(for origin: String) -> Bool {
        var state = states[origin, default: State()]
        guard state.consecutiveH3Failures >= h3FailureThreshold else {
            states[origin] = state
            return false
        }
        state.tcpPreferredUntil = Date().addingTimeInterval(cooldownDuration)
        states[origin] = state
        return true
    }

    func recordTCPFailure(for origin: String) {
        var state = states[origin, default: State()]
        state.consecutiveH3Failures = 0
        state.tcpPreferredUntil = nil
        states[origin] = state
    }

    func reset() {
        states.removeAll()
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

import Foundation

struct TranslationNetworkClient: Sendable {
    private let session: URLSession

    nonisolated init(session: URLSession = .shared) {
        self.session = session
    }

    func get(url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        do {
            return try await session.data(for: request)
        } catch {
            throw TranslateError.networkError(underlying: error)
        }
    }

    func post(url: URL, body: Data?, headers: [String: String] = [:]) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.httpBody = body

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            return try await session.data(for: request)
        } catch {
            throw TranslateError.networkError(underlying: error)
        }
    }
}

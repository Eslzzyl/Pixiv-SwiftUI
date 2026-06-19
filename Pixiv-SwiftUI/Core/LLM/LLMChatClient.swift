import Foundation

struct LLMChatClient: Sendable {
    let baseURL: String
    let apiKey: String

    nonisolated init(baseURL: String = "https://api.openai.com/v1", apiKey: String = "") {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    func chatCompletion(
        model: String,
        messages: [LLMMessage],
        temperature: Double
    ) async throws -> LLMChatResponse {
        guard let url = URL(string: baseURL)?.appendingPathComponent("chat/completions") else {
            throw LLMChatClientError.invalidURL
        }

        let body = LLMChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            stream: false
        )

        var headers = ["Content-Type": "application/json"]
        if !apiKey.isEmpty {
            headers["Authorization"] = "Bearer \(apiKey)"
        }

        let bodyData = try JSONEncoder().encode(body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.httpBody = bodyData
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMChatClientError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMChatClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw LLMChatClientError.unauthorized
        case 429:
            throw LLMChatClientError.rateLimited
        case 500...599:
            throw LLMChatClientError.serverError
        default:
            if let errorResponse = try? JSONDecoder().decode(LLMErrorResponse.self, from: data),
               let message = errorResponse.error?.message {
                throw LLMChatClientError.apiError(message)
            }
            throw LLMChatClientError.httpError(statusCode: httpResponse.statusCode)
        }

        let chatResponse = try JSONDecoder().decode(LLMChatResponse.self, from: data)
        guard chatResponse.choices.first != nil else {
            throw LLMChatClientError.emptyResponse
        }

        return chatResponse
    }
}

enum LLMChatClientError: Error, LocalizedError {
    case invalidURL
    case networkError(underlying: any Error)
    case invalidResponse
    case unauthorized
    case rateLimited
    case serverError
    case apiError(String)
    case httpError(statusCode: Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized: Invalid API key"
        case .rateLimited:
            return "Rate limit exceeded"
        case .serverError:
            return "Server error"
        case .apiError(let message):
            return "API error: \(message)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .emptyResponse:
            return "Empty response from LLM"
        }
    }
}

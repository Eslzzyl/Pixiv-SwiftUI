import Foundation

enum TranslateError: Error, LocalizedError, Sendable {
    case invalidURL
    case requestFailed(statusCode: Int)
    case invalidResponse
    case parsingError
    case signatureError
    case networkError(underlying: any Error)
    case languageNotSupported(String)
    case unauthorized
    case rateLimited
    case serverError
    case apiError(String)
    case missingSecret
    case invalidSecretFormat(String)
    case tokenExpired
    case tokenFetchFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed(let code):
            return "Request failed with status code: \(code)"
        case .invalidResponse:
            return "Invalid response from server"
        case .parsingError:
            return "Failed to parse response"
        case .signatureError:
            return "Failed to generate signature"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .languageNotSupported(let code):
            return "Language code not supported: \(code)"
        case .unauthorized:
            return "Unauthorized: Invalid API key"
        case .rateLimited:
            return "Rate limit exceeded"
        case .serverError:
            return "Server error"
        case .apiError(let message):
            return "API error: \(message)"
        case .missingSecret:
            return "API secret is required but was not provided"
        case .invalidSecretFormat(let message):
            return "Invalid secret format: \(message)"
        case .tokenExpired:
            return "Authentication token has expired"
        case .tokenFetchFailed:
            return "Failed to fetch authentication token"
        }
    }
}

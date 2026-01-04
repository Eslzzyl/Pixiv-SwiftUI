import Foundation
import CommonCrypto

public final class OAuthClient: @unchecked Sendable {
    public static let shared = OAuthClient()
    
    let hashSalt = "28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c"
    
    let clientId = "MOBrBDS8blbauoSck0ZfDbtuzpyT"
    let clientSecret = "lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'+00:00'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private init() {}
    
    func getIsoDate() -> String {
        let now = Date()
        return dateFormatter.string(from: now)
    }
    
    func getHash(_ string: String) -> String {
        let data = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    func buildHeaders() -> [String: String] {
        let time = getIsoDate()
        let hash = getHash(time + hashSalt)
        
        return [
            "X-Client-Time": time,
            "X-Client-Hash": hash,
            "User-Agent": "PixivAndroidApp/5.0.155 (Android 6.0; Pixel C)",
            "Accept-Language": "zh-CN",
            "App-OS": "Android",
            "App-OS-Version": "Android 6.0",
            "App-Version": "5.0.166",
            "Content-Type": "application/x-www-form-urlencoded"
        ]
    }
    
    func buildRefreshTokenBody(refreshToken: String) -> Data? {
        var components: [String] = []
        components.append("grant_type=refresh_token")
        components.append("refresh_token=\(refreshToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? refreshToken)")
        components.append("client_id=\(clientId)")
        components.append("client_secret=\(clientSecret)")
        components.append("include_policy=true")
        
        let body = components.joined(separator: "&")
        return body.data(using: .utf8)
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func refreshToken(_ refreshToken: String) async throws -> TokenResponse {
        let headers = buildHeaders()
        let body = buildRefreshTokenBody(refreshToken: refreshToken)
        
        let (data, response) = try await DirectConnection.shared.request(
            endpoint: .oauth,
            path: "/auth/token",
            method: "POST",
            headers: headers,
            body: body
        )
        
        guard (200...299).contains(response.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? [String: Any],
               let message = errorMessage["message"] as? String {
                throw OAuthError.serverError(message)
            } else {
                throw OAuthError.httpError(response.statusCode)
            }
        }
        
        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
        return tokenResponse
    }
}

public enum OAuthError: LocalizedError {
    case httpError(Int)
    case serverError(String)
    case invalidResponse
    case decodingError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

import Foundation
import CryptoKit

/// 认证相关API
@MainActor
final class AuthAPI {
    private let client = NetworkClient.shared
    private var accessToken: String?

    private let hashSalt = "28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c"
    private let appUserAgent = "PixivIOSApp/7.13.3 (iOS 14.6; iPhone13,2)"

    /// 设置访问令牌
    func setAccessToken(_ token: String) {
        self.accessToken = token
    }

    /// 获取基础请求头（包含 X-Client-Hash 等）
    private var baseHeaders: [String: String] {
        var headers = [String: String]()
        let time = getIsoDate()
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        let acceptLanguage = (langCode == "zh" || langCode.hasPrefix("zh-")) ? "zh-CN" : "en-US"

        headers["X-Client-Time"] = time
        headers["X-Client-Hash"] = getHash(time + hashSalt)
        headers["App-OS"] = "ios"
        headers["App-OS-Version"] = "14.6"
        headers["App-Version"] = "7.13.3"
        headers["Accept-Language"] = acceptLanguage
        headers["Accept"] = "application/json"
        headers["User-Agent"] = appUserAgent
        return headers
    }

    /// 获取授权请求头
    private var authHeaders: [String: String] {
        var headers = baseHeaders
        if let token = accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        headers["Accept"] = "application/json"
        headers["Content-Type"] = "application/json"
        return headers
    }

    private func getIsoDate() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }

    private func getHash(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }

    /// 使用 code 登录
    func loginWithCode(_ code: String, codeVerifier: String) async throws -> (
        accessToken: String, refreshToken: String, user: User, expiresIn: Int
    ) {
        // swiftlint:disable:next force_unwrapping
        let url = URL(string: APIEndpoint.oauthURL + "/auth/token")!

        let formEncodedData = try makeFormData([
            ("client_id", "MOBrBDS8blbauoSck0ZfDbtuzpyT"),
            ("client_secret", "lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"),
            ("grant_type", "authorization_code"),
            ("code", code),
            ("code_verifier", codeVerifier),
            ("redirect_uri", "https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback"),
            ("include_policy", "true"),
        ])

        struct AuthResponse: Decodable {
            let accessToken: String
            let refreshToken: String?
            let user: UserDTO
            let expiresIn: Int

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case user
                case expiresIn = "expires_in"
            }
        }

        let response = try await client.post(
            to: url,
            body: formEncodedData,
            headers: baseHeaders.merging(["Content-Type": "application/x-www-form-urlencoded"], uniquingKeysWith: { (_, new) in new }),
            responseType: AuthResponse.self
        )

        self.accessToken = response.accessToken

        return (
            response.accessToken,
            response.refreshToken ?? "",
            response.user.toDomain(),
            response.expiresIn
        )
    }

    /// 使用 refresh_token 登录
    func loginWithRefreshToken(_ refreshToken: String) async throws -> (
        accessToken: String, user: User, expiresIn: Int
    ) {
        let (accessToken, _, user, expiresIn) = try await refreshAccessToken(refreshToken)
        return (accessToken, user, expiresIn)
    }

    /// 刷新 accessToken
    func refreshAccessToken(_ refreshToken: String) async throws -> (
        accessToken: String, refreshToken: String, user: User, expiresIn: Int
    ) {
        // swiftlint:disable:next force_unwrapping
        let url = URL(string: APIEndpoint.oauthURL + "/auth/token")!

        let formEncodedData = try makeFormData([
            ("client_id", "MOBrBDS8blbauoSck0ZfDbtuzpyT"),
            ("client_secret", "lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"),
            ("grant_type", "refresh_token"),
            ("refresh_token", refreshToken),
            ("get_secure_url", "true"),
        ])

        struct AuthResponse: Decodable {
            let accessToken: String
            let refreshToken: String?
            let user: UserDTO
            let expiresIn: Int

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case user
                case expiresIn = "expires_in"
            }
        }

        let response = try await client.post(
            to: url,
            body: formEncodedData,
            headers: baseHeaders.merging(["Content-Type": "application/x-www-form-urlencoded"], uniquingKeysWith: { (_, new) in new }),
            responseType: AuthResponse.self
        )

        self.accessToken = response.accessToken

        return (
            response.accessToken,
            response.refreshToken ?? refreshToken,
            response.user.toDomain(),
            response.expiresIn
        )
    }

    private func makeFormData(_ fields: [(String, String)]) throws -> Data {
        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name: $0.0, value: $0.1) }

        guard let formData = components.percentEncodedQuery?.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }

        return formData
    }
}

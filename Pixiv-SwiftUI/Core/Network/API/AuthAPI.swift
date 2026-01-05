import Foundation
import CryptoKit

/// 认证相关API
final class AuthAPI {
    private let client = NetworkClient.shared
    private var accessToken: String?
    
    private let hashSalt = "28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c"

    /// 设置访问令牌
    func setAccessToken(_ token: String) {
        self.accessToken = token
    }

    /// 获取基础请求头（包含 X-Client-Hash 等）
    private var baseHeaders: [String: String] {
        var headers = [String: String]()
        let time = getIsoDate()
        headers["X-Client-Time"] = time
        headers["X-Client-Hash"] = getHash(time + hashSalt)
        headers["App-OS"] = "ios"
        headers["App-OS-Version"] = "14.6"
        headers["App-Version"] = "7.13.3"
        headers["Accept-Language"] = "zh-CN"
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
        accessToken: String, refreshToken: String, user: User
    ) {
        let url = URL(string: APIEndpoint.oauthURL + "/auth/token")!

        var body = [String: String]()
        body["client_id"] = "MOBrBDS8blbauoSck0ZfDbtuzpyT"
        body["client_secret"] = "lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"
        body["grant_type"] = "authorization_code"
        body["code"] = code
        body["code_verifier"] = codeVerifier
        body["redirect_uri"] = "https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback"
        body["include_policy"] = "true"

        var components = URLComponents()
        components.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
        let formData = components.percentEncodedQuery ?? ""

        guard let formEncodedData = formData.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }

        struct AuthResponse: Decodable {
            let accessToken: String
            let refreshToken: String?
            let user: User

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case user
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
            response.user
        )
    }

    /// 使用 refresh_token 登录
    func loginWithRefreshToken(_ refreshToken: String) async throws -> (
        accessToken: String, user: User
    ) {
        let (accessToken, _, user) = try await refreshAccessToken(refreshToken)
        return (accessToken, user)
    }

    /// 刷新 accessToken
    func refreshAccessToken(_ refreshToken: String) async throws -> (
        accessToken: String, refreshToken: String, user: User
    ) {
        let url = URL(string: APIEndpoint.oauthURL + "/auth/token")!

        var body = [String: String]()
        body["client_id"] = "MOBrBDS8blbauoSck0ZfDbtuzpyT"
        body["client_secret"] = "lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"
        body["grant_type"] = "refresh_token"
        body["refresh_token"] = refreshToken
        body["include_policy"] = "true"

        var components = URLComponents()
        components.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
        let formData = components.percentEncodedQuery ?? ""

        guard let formEncodedData = formData.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }

        struct AuthResponse: Decodable {
            let accessToken: String
            let refreshToken: String?
            let user: User

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case user
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
            response.user
        )
    }
}
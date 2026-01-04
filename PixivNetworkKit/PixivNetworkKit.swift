import Foundation

/// PixivNetworkKit
///
/// A minimal direct connection network layer for Pixiv API using Network.framework.
///
/// ## Overview
///
/// This library bypasses DNS pollution and SNI blocking by directly connecting to
/// Pixiv's IP addresses and setting the SNI hostname manually.
///
/// ## Usage
///
/// ```swift
/// import PixivNetworkKit
///
/// let client = OAuthClient.shared
/// let response = try await client.refreshToken("your_refresh_token")
/// print(response.response.accessToken)
/// ```
///
/// ## Requirements
///
/// - iOS 12.0+ / macOS 10.14+ / tvOS 12.0+ / watchOS 6.0+
/// - Swift 5.9+
///
/// ## License
///
/// MIT License
public enum PixivNetworkKit {
    public static let version: String = "1.0.0"
}

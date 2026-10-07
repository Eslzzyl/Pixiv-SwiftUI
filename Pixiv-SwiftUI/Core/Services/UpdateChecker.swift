import Foundation
import os.log

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String?
    let htmlUrl: String
    let assets: [ReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

struct ReleaseAsset: Codable {
    let name: String
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}

enum UpdateCheckerError: LocalizedError {
    case networkError(String)
    case decodingError(String)
    case noReleaseFound

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "网络错误: \(message)"
        case .decodingError(let message):
            return "解析错误: \(message)"
        case .noReleaseFound:
            return "未找到发布版本"
        }
    }
}

struct AppUpdateInfo: Identifiable {
    let id = UUID()
    let version: String
    let releaseName: String
    let releaseNotes: String
    let releaseUrl: String
    let downloadUrl: String?

    var isNewerThanCurrent: Bool {
        guard let currentVersion = currentAppVersion else { return false }
        return compareVersions(new: version, current: currentVersion) > 0
    }

    private var currentAppVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private func compareVersions(new: String, current: String) -> Int {
        let newComponents = new.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            .split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            .split(separator: ".").compactMap { Int($0) }

        let maxLength = max(newComponents.count, currentComponents.count)

        for i in 0..<maxLength {
            let newPart = i < newComponents.count ? newComponents[i] : 0
            let currentPart = i < currentComponents.count ? currentComponents[i] : 0

            if newPart > currentPart {
                return 1
            } else if newPart < currentPart {
                return -1
            }
        }

        return 0
    }
}

@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    private let githubAPIURL = "https://api.github.com/repos/Eslzzyl/Pixiv-SwiftUI/releases/latest"
    private let session: URLSession

    private let skippedUpdateVersionKey = "skippedUpdateVersion"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    func skipVersion(_ version: String) {
        UserDefaults.standard.set(
            normalizedVersion(version),
            forKey: skippedUpdateVersionKey
        )
    }

    func isVersionSkipped(_ version: String) -> Bool {
        guard let skippedVersion = UserDefaults.standard.string(forKey: skippedUpdateVersionKey) else {
            return false
        }

        return skippedVersion == normalizedVersion(version)
    }

    private func normalizedVersion(_ version: String) -> String {
        version.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
    }

    func checkForUpdate() async -> AppUpdateInfo? {
        guard let url = URL(string: githubAPIURL) else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }

            if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 {
                Logger.updater.debug("API rate limited, falling back to HTML parsing")
                return await checkForUpdateFromHTML()
            }

            guard httpResponse.statusCode == 200 else {
                Logger.updater.debug("API returned status code: \(httpResponse.statusCode)")
                return await checkForUpdateFromHTML()
            }

            let decoder = JSONDecoder()
            let release = try decoder.decode(GitHubRelease.self, from: data)

            let downloadUrl = findDownloadUrl(for: release)

            let updateInfo = AppUpdateInfo(
                version: release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v")),
                releaseName: release.name,
                releaseNotes: release.body ?? "暂无更新日志",
                releaseUrl: release.htmlUrl,
                downloadUrl: downloadUrl
            )

            return updateInfo
        } catch {
            Logger.updater.error("Failed to check for update: \(error.localizedDescription, privacy: .public)")
            return await checkForUpdateFromHTML()
        }
    }

    private func checkForUpdateFromHTML() async -> AppUpdateInfo? {
        let htmlURL = "https://github.com/Eslzzyl/Pixiv-SwiftUI/releases/latest"

        guard let url = URL(string: htmlURL) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                Logger.updater.debug("Failed to fetch HTML page")
                return nil
            }

            guard let redirectURL = httpResponse.url else {
                Logger.updater.debug("No redirect URL found")
                return nil
            }

            let tagPattern = "/releases/tag/([^/\"]+)"
            guard let regex = try? NSRegularExpression(pattern: tagPattern),
                  let match = regex.firstMatch(in: redirectURL.absoluteString, range: NSRange(redirectURL.absoluteString.startIndex..., in: redirectURL.absoluteString)),
                  let range = Range(match.range(at: 1), in: redirectURL.absoluteString) else {
                Logger.updater.debug("Could not extract version tag from URL")
                return nil
            }

            let versionTag = String(redirectURL.absoluteString[range])
            let version = versionTag.trimmingCharacters(in: CharacterSet(charactersIn: "v"))

            var releaseNotes = "暂无更新日志"
            if let titleRegex = try? NSRegularExpression(pattern: ">([^<]+) Release"),
               let titleMatch = titleRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let titleRange = Range(titleMatch.range(at: 1), in: html) {
                releaseNotes = String(html[titleRange])
            }

            let updateInfo = AppUpdateInfo(
                version: version,
                releaseName: versionTag,
                releaseNotes: releaseNotes,
                releaseUrl: redirectURL.absoluteString,
                downloadUrl: nil
            )

            return updateInfo
        } catch {
            Logger.updater.error("Failed to parse HTML: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func findDownloadUrl(for release: GitHubRelease) -> String? {
        #if os(macOS)
        let preferredNames = ["Pixiv-SwiftUI-arm64.dmg", "Pixiv-SwiftUI-x86_64.dmg"]
        #elseif os(iOS)
        let preferredNames = ["Pixiv-SwiftUI.ipa"]
        #else
        let preferredNames: [String] = []
        #endif

        for name in preferredNames {
            if let asset = release.assets.first(where: { $0.name == name }) {
                return asset.browserDownloadUrl
            }
        }

        return release.assets.first?.browserDownloadUrl
    }

    var currentAppVersion: String? {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            return nil
        }
        return "\(version) (Build \(build))"
    }
}

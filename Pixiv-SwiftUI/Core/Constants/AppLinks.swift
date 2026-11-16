import Foundation

/// 应用对外链接的唯一来源，避免仓库地址在多个界面中各自维护而出现偏差。
enum AppLinks {
    private static let githubHost = "https://github.com"
    private static let githubAPIHost = "https://api.github.com"
    private static let repositoryPath = "Eslzzyl/Pixiv-SwiftUI"

    /// 项目仓库主页
    static let repository = "\(githubHost)/\(repositoryPath)"
    /// 版本发布列表
    static let releases = "\(repository)/releases"
    /// 最新版本发布页
    static let latestRelease = "\(releases)/latest"
    /// 问题反馈
    static let issues = "\(repository)/issues"
    /// 项目 Wiki
    static let wiki = "\(repository)/wiki"
    /// GitHub Releases API
    static let latestReleaseAPI = "\(githubAPIHost)/repos/\(repositoryPath)/releases/latest"
    /// Pixiv 官网
    static let pixiv = "https://www.pixiv.net"
}

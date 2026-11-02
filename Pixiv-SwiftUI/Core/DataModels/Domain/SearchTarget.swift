import Foundation

/// 搜索导航目标
struct SearchResultTarget: Hashable, Sendable {
    let word: String
}

struct SauceNaoMatch: Hashable, Sendable {
    let illustId: Int
    let similarity: Double?
}

/// SauceNAO 以图搜图导航目标
struct SauceNaoResultTarget: Hashable, Sendable {
    let requestId: UUID
}

/// 基于标签推荐的导航目标
struct RecommendByTagTarget: Hashable, Sendable {
    let tag: String
    let translatedName: String?
    let illustIds: [Int]
}

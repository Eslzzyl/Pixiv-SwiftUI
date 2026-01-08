import Foundation

/// 小说排行榜模式
enum NovelRankingMode: String, CaseIterable, Identifiable {
    case day = "day"
    case dayMale = "day_male"
    case dayFemale = "day_female"
    case week = "week"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            return "每日"
        case .dayMale:
            return "男性向"
        case .dayFemale:
            return "女性向"
        case .week:
            return "每周"
        }
    }
}

/// 小说排行榜响应
struct NovelRankingResponse: Codable {
    let novels: [Novel]
    let nextUrl: String?
    let rankingNovels: [RankingNovel]?
    let nextUrlRanking: String?

    enum CodingKeys: String, CodingKey {
        case novels
        case nextUrl = "next_url"
        case rankingNovels = "ranking_novels"
        case nextUrlRanking = "next_url_ranking"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        novels = try container.decodeIfPresent([Novel].self, forKey: .novels) ?? []
        nextUrl = try container.decodeIfPresent(String.self, forKey: .nextUrl)
        rankingNovels = try container.decodeIfPresent([RankingNovel].self, forKey: .rankingNovels)
        nextUrlRanking = try container.decodeIfPresent(String.self, forKey: .nextUrlRanking)
    }

    init(novels: [Novel], nextUrl: String?) {
        self.novels = novels
        self.nextUrl = nextUrl
        self.rankingNovels = nil
        self.nextUrlRanking = nil
    }
}

/// 排行榜中的小说（包含排名信息）
struct RankingNovel: Codable {
    let novel: Novel
    let rank: Int
    let previousRank: Int?
    let change: Int?

    enum CodingKeys: String, CodingKey {
        case novel
        case rank
        case previousRank = "previous_rank"
        case change
    }
}

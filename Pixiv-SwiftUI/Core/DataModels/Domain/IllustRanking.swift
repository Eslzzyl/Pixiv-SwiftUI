import Foundation

/// 插画排行榜模式
enum IllustRankingMode: String, CaseIterable, Identifiable {
    case day = "day"
    case dayMale = "day_male"
    case dayFemale = "day_female"
    case week = "week"
    case month = "month"
    case weekOriginal = "week_original"
    case weekRookie = "week_rookie"

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
        case .month:
            return "每月"
        case .weekOriginal:
            return "原创"
        case .weekRookie:
            return "新人"
        }
    }
}

/// 插画排行榜响应
struct IllustRankingResponse: Codable {
    let illusts: [Illusts]
    let nextUrl: String?

    enum CodingKeys: String, CodingKey {
        case illusts
        case nextUrl = "next_url"
    }
}

/// 排行榜中的插画（包含排名信息）
struct RankingIllust: Codable {
    let illust: Illusts
    let rank: Int
    let previousRank: Int?
    let change: Int?

    enum CodingKeys: String, CodingKey {
        case illust
        case rank
        case previousRank = "previous_rank"
        case change
    }
}

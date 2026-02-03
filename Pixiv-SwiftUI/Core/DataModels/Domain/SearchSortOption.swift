import Foundation

enum SearchSortOption: String, CaseIterable {
    case dateDesc = "date_desc"
    case dateAsc = "date_asc"
    case popularDesc = "popular_desc"

    var displayName: String {
        switch self {
        case .dateDesc: return String(localized: "发布时间（从新到旧）")
        case .dateAsc: return String(localized: "发布时间（从旧到新）")
        case .popularDesc: return String(localized: "热门排序（仅会员）")
        }
    }

    var requiresPremium: Bool {
        self == .popularDesc
    }
}
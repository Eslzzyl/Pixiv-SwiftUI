import Foundation

enum NovelListType: Hashable {
    case recommend
    case following
    case bookmarks(userId: String, restrict: String = "public")

    var title: String {
        switch self {
        case .recommend:
            return "推荐"
        case .following:
            return "关注新作"
        case .bookmarks:
            return "收藏"
        }
    }
}

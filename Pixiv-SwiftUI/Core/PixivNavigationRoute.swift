import Observation
import SwiftUI

/// 应用内统一导航路由。
enum PixivNavigationRoute: Hashable {
    case illust(id: Int, sessionID: UUID, transitionNamespace: Namespace.ID?)
    case novel(id: Int)
    case novelDetail(novel: Novel, transitionNamespace: Namespace.ID?)
    case user(id: String)
    case illustLoader(id: Int)
    case novelLoader(id: Int)
    case novelReader(id: Int)
    case illustSeries(id: Int)
    case novelSeries(id: Int)
    case search(SearchResultTarget)
    case recommendByTag(RecommendByTagTarget)
    case novelRanking(NovelRankingType)
    case illustRanking(IllustRankingType)
    case spotlightList
    case spotlightArticle(SpotlightArticle)
    case spotlightRelatedArticle(SpotlightRelatedArticle)
    case sauceNao(requestID: UUID)
    case followingList(userID: String)
    case recommendedArtists
    case novelList(NovelListType)
    case deletedBookmark(illustID: Int, ownerID: String)
    case profile(ProfileDestination)
}

/// 单个导航栈的状态所有者。
@MainActor
@Observable
final class PixivNavigationRouter {
    var path: [PixivNavigationRoute] = []

    /// 将路由压入当前导航栈。
    func push(_ route: PixivNavigationRoute) {
        path.append(route)
    }

    /// 清空当前栈并打开指定路由。
    func replace(with route: PixivNavigationRoute) {
        path = []
        path.append(route)
    }

    /// 返回当前导航栈根节点。
    func popToRoot() {
        path = []
    }
}

extension EnvironmentValues {
    @Entry var pixivNavigationRouter: PixivNavigationRouter?
}

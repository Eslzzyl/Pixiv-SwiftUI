import SwiftUI

extension View {
    /// 注册应用内统一导航目的地。
    func pixivNavigationDestinations() -> some View {
        self
            .navigationDestination(for: PixivNavigationRoute.self) { route in
                PixivNavigationDestination(route: route)
            }
    }
}

struct PixivNavigationStack<Content: View>: View {
    @State private var navigationRouter = PixivNavigationRouter()
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        @Bindable var navigationRouter = navigationRouter

        return NavigationStack(path: $navigationRouter.path) {
            content()
                .pixivNavigationDestinations()
        }
        .environment(navigationRouter)
    }
}

private struct PixivNavigationDestination: View {
    let route: PixivNavigationRoute

    @ViewBuilder
    var body: some View {
        switch route {
        case .illust(let id, let sessionID, let transitionNamespace):
            if let session = IllustDetailNavigationSessionStore.shared.session(for: sessionID),
               let illust = session.initialContext.first(where: { $0.id == id }) {
                pixivDetailDestination(
                    IllustDetailBrowserView(illust: illust, session: session),
                    sourceID: id,
                    transitionNamespace: transitionNamespace
                )
            } else {
                pixivDetailDestination(
                    IllustLoaderView(illustId: id),
                    sourceID: id,
                    transitionNamespace: transitionNamespace
                )
            }
        case .novel(let id):
            NovelLoaderView(novelId: id)
        case .novelDetail(let novel, let transitionNamespace):
            pixivDetailDestination(
                NovelDetailView(novel: novel),
                sourceID: novel.id,
                transitionNamespace: transitionNamespace
            )
        case .user(let id):
            UserDetailView(userId: id)
        case .illustLoader(let id):
            IllustLoaderView(illustId: id)
        case .novelLoader(let id):
            NovelLoaderView(novelId: id)
        case .novelReader(let id):
            NovelReaderView(novelId: id)
        case .illustSeries(let id):
            IllustSeriesView(seriesId: id)
        case .novelSeries(let id):
            NovelSeriesView(seriesId: id)
        case .search(let target):
            SearchResultView(word: target.word, preloadToken: target.preloadToken)
        case .recommendByTag(let target):
            RecommendByTagView(target: target)
        case .novelRanking(let type):
            NovelRankingPage(initialMode: type.mode)
        case .illustRanking(let type):
            IllustRankingPage(initialMode: type.mode)
        case .spotlightList:
            SpotlightListView()
        case .spotlightArticle(let article):
            SpotlightDetailView(article: article)
        case .spotlightRelatedArticle(let article):
            SpotlightDetailView(
                article: SpotlightArticle(
                    id: article.id,
                    title: article.title,
                    pureTitle: article.title,
                    thumbnail: article.thumbnail,
                    articleUrl: article.articleUrl,
                    publishDate: Date(),
                    category: article.category
                )
            )
        case .sauceNao(let requestID):
            SauceNaoResultListView(requestId: requestID)
        case .followingList(let userID):
            FollowingListView(store: FollowingListStore(), userId: userID)
        case .recommendedArtists:
            RecommendedUsersListView()
        case .novelList(let listType):
            NovelListPage(listType: listType)
        case .deletedBookmark(let illustID, let ownerID):
            if let cache = BookmarkCacheStore.shared.getCacheRecord(illustId: illustID, ownerId: ownerID) {
                DeletedBookmarkDetailView(cache: cache)
            } else {
                ContentUnavailableView(
                    "缓存记录不可用",
                    systemImage: "exclamationmark.triangle",
                    description: Text("无法打开已删除的收藏记录")
                )
            }
        case .profile(let destination):
            switch destination {
            case .userDetail(let userID):
                UserDetailView(userId: userID)
            case .browseHistory:
                BrowseHistoryView()
            case .settings:
                ProfileSettingView(isPresented: .constant(false))
            case .downloadTasks:
                DownloadTasksView()
            case .blockSettings:
                BlockSettingView()
            case .translationSettings:
                TranslationSettingView()
            case .syncSettings:
                WebDAVSyncSettingsView()
            case .downloadSettings:
                DownloadSettingView()
            case .networkSettings:
                NetworkSettingsView()
            case .dataExport:
                DataExportView()
            case .about:
                AboutSettingsView()
            case .appearance:
                ThemeSettingsView()
            case .privacy:
                PrivacySettingsView()
            }
        }
    }

    @ViewBuilder
    private func pixivDetailDestination<Content: View>(
        _ content: Content,
        sourceID: Int,
        transitionNamespace: Namespace.ID?
    ) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *), let transitionNamespace {
            content
                .navigationTransition(.zoom(sourceID: sourceID, in: transitionNamespace))
        } else {
            content
        }
        #else
        content
        #endif
    }
}

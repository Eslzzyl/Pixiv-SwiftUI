import SwiftUI
import os.log

extension View {
    /// 通用的 Pixiv 导航目标
    func pixivNavigationDestinations() -> some View {
        self
            .navigationDestination(for: IllustIdTarget.self) { target in
                IllustLoaderView(illustId: target.id)
            }
            .navigationDestination(for: NovelIdTarget.self) { target in
                NovelLoaderView(novelId: target.id)
            }
            .navigationDestination(for: Illusts.self) { illust in
                IllustDetailBrowserView(illust: illust)
                    .onAppear {
                        Logger.ui.debug("Illusts destination triggered: \(illust.id), type=\(illust.type)")
                    }
            }
            .navigationDestination(for: IllustDetailNavigationTarget.self) { target in
                IllustDetailBrowserView(target: target)
            }
            .navigationDestination(for: Novel.self) { novel in
                NovelDetailView(novel: novel)
                    .onAppear {
                        Logger.ui.debug("Novel destination triggered: id=\(novel.id), title=\(novel.title)")
                    }
            }
            .navigationDestination(for: NovelSeries.self) { series in
                NovelSeriesView(seriesId: series.id ?? 0)
                    .onAppear {
                        Logger.ui.debug("NovelSeries destination triggered: seriesId=\(series.id ?? 0)")
                    }
            }
            .navigationDestination(for: IllustSeries.self) { series in
                IllustSeriesView(seriesId: series.id)
                    .onAppear {
                        Logger.ui.debug("IllustSeries destination triggered: seriesId=\(series.id)")
                    }
            }
            .navigationDestination(for: User.self) { user in
                UserDetailView(userId: user.id.stringValue)
                    .onAppear {
                        Logger.ui.debug("User destination triggered: \(user.id.stringValue)")
                    }
            }
            .navigationDestination(for: UserDetailUser.self) { userDetailUser in
                UserDetailView(userId: String(userDetailUser.id))
                    .onAppear {
                        Logger.ui.debug("UserDetailUser destination triggered: \(userDetailUser.id)")
                    }
            }
            .navigationDestination(for: SearchResultTarget.self) { target in
                SearchResultView(word: target.word, preloadToken: target.preloadToken)
                    .onAppear {
                        Logger.ui.debug("SearchResultTarget destination triggered: \(target.word)")
                    }
            }
            .navigationDestination(for: RecommendByTagTarget.self) { target in
                RecommendByTagView(target: target)
            }
            .navigationDestination(for: NovelRankingType.self) { _ in
                NovelRankingPage()
                    .onAppear {
                        Logger.ui.debug("NovelRankingPage destination triggered")
                    }
            }
            .navigationDestination(for: IllustRankingType.self) { type in
                IllustRankingPage(initialMode: type.mode)
                    .onAppear {
                        Logger.ui.debug("IllustRankingPage destination triggered with mode: \(type.mode.title)")
                    }
            }
            .navigationDestination(for: SpotlightListTarget.self) { _ in
                SpotlightListView()
            }
    }
}

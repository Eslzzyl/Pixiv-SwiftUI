import SwiftUI

extension View {
    /// 通用的 Pixiv 导航目标
    func pixivNavigationDestinations() -> some View {
        self
            .navigationDestination(for: Illusts.self) { illust in
                IllustDetailView(illust: illust)
                    .onAppear {
                        print(
                            "[pixivNavigationDestinations] Illusts destination triggered: \(illust.id), type=\(illust.type)"
                        )
                    }
            }
            .navigationDestination(for: Novel.self) { novel in
                NovelDetailView(novel: novel)
                    .onAppear {
                        print(
                            "[pixivNavigationDestinations] Novel destination triggered: id=\(novel.id), title=\(novel.title)"
                        )
                    }
            }
            .navigationDestination(for: NovelSeries.self) { series in
                NovelSeriesView(seriesId: series.id ?? 0)
                    .onAppear {
                        print(
                            "[pixivNavigationDestinations] NovelSeries destination triggered: seriesId=\(series.id ?? 0)"
                        )
                    }
            }
            .navigationDestination(for: User.self) { user in
                UserDetailView(userId: user.id.stringValue)
                    .onAppear {
                        print(
                            "[pixivNavigationDestinations] User destination triggered: \(user.id.stringValue)"
                        )
                    }
            }
            .navigationDestination(for: UserDetailUser.self) { userDetailUser in
                UserDetailView(userId: String(userDetailUser.id))
                    .onAppear {
                        print(
                            "[pixivNavigationDestinations] UserDetailUser destination triggered: \(userDetailUser.id)"
                        )
                    }
            }
            .navigationDestination(for: SearchResultTarget.self) { target in
                SearchResultView(word: target.word)
                    .onAppear {
                        print(
                            "[pixivNavigationDestinations] SearchResultTarget destination triggered: \(target.word)"
                        )
                    }
            }
            .navigationDestination(for: NovelRankingType.self) { _ in
                NovelRankingPage()
                    .onAppear {
                        print(
                            "[pixivNavigationDestinations] NovelRankingPage destination triggered"
                        )
                    }
            }
            .navigationDestination(for: IllustRankingType.self) { _ in
                IllustRankingPage()
                    .onAppear {
                        print(
                            "[pixivNavigationDestinations] IllustRankingPage destination triggered"
                        )
                    }
            }
    }
}

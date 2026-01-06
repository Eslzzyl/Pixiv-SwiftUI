import SwiftUI

extension View {
    /// 通用的 Pixiv 导航目标
    func pixivNavigationDestinations() -> some View {
        self
            .navigationDestination(for: Illusts.self) { illust in
                IllustDetailView(illust: illust)
            }
            .navigationDestination(for: Novel.self) { novel in
                NovelDetailView(novel: novel)
            }
            .navigationDestination(for: User.self) { user in
                UserDetailView(userId: user.id.stringValue)
            }
            .navigationDestination(for: UserDetailUser.self) { userDetailUser in
                UserDetailView(userId: String(userDetailUser.id))
            }
            .navigationDestination(for: SearchResultTarget.self) { target in
                SearchResultView(word: target.word)
            }
    }
}

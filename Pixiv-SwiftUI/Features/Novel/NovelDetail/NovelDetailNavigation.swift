import SwiftUI

/// 小说卡片到小说详情页的导航链接，支持 iOS 18+ 的缩放转场效果。
struct NovelDetailNavigationLink<Label: View>: View {
    let novel: Novel
    private let label: () -> Label
    @Namespace private var transitionNamespace

    init(novel: Novel, @ViewBuilder label: @escaping () -> Label) {
        self.novel = novel
        self.label = label
    }

    var body: some View {
        NavigationLink(
            value: PixivNavigationRoute.novelDetail(
                novel: novel,
                transitionNamespace: transitionNamespace
            )
        ) {
            sourceLabel
        }
    }

    @ViewBuilder
    private var sourceLabel: some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            label()
                .matchedTransitionSource(id: novel.id, in: transitionNamespace)
        } else {
            label()
        }
        #else
        label()
        #endif
    }

}

#Preview("小说卡片转场链接") {
    let sampleNovel = Novel(
        id: 12345,
        title: "示例小说标题",
        caption: "小说简介",
        restrict: 0,
        xRestrict: 0,
        isOriginal: false,
        imageUrls: ImageUrlsDTO(
            squareMedium: "",
            medium: "",
            large: ""
        ),
        createDate: "2026-01-01",
        tags: [],
        pageCount: 1,
        textLength: 3000,
        user: UserDTO(
            profileImageUrls: ProfileImageUrlsDTO(px50x50: ""),
            id: StringIntValue.string("1"),
            name: "示例作者",
            account: "sample_author",
            mailAddress: nil,
            isPremium: nil,
            xRestrict: nil,
            isMailAuthorized: nil,
            requirePolicyAgreement: nil,
            isAcceptRequest: nil,
            isFollowed: nil
        ),
        series: nil,
        isBookmarked: false,
        totalBookmarks: 100,
        totalView: 500,
        visible: true,
        isMuted: false,
        isMypixivOnly: false,
        isXRestricted: false,
        novelAIType: 0
    )

    NavigationStack {
        NovelDetailNavigationLink(novel: sampleNovel) {
            Text("打开示例小说")
                .padding()
        }
    }
}

import SwiftUI

struct NovelWaterfallView: View {
    let novels: [Novel]
    let isLoadingMore: Bool
    let hasReachedEnd: Bool
    let onLoadMore: () -> Void
    @Environment(UserSettingStore.self) var settingStore

    private var filteredNovels: [Novel] {
        settingStore.filterNovels(novels)
    }

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredNovels) { novel in
                NovelRowView(novel: novel)
            }

            if !hasReachedEnd {
                ProgressView()
                    #if os(macOS)
                    .controlSize(.small)
                    #endif
                    .padding()
                    .onAppear {
                        onLoadMore()
                    }
            } else {
                Text("已经到底了")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding(.horizontal, 12)
    }
}

struct NovelRowView: View {
    let novel: Novel

    var body: some View {
        NavigationLink(value: novel) {
            NovelInfoTableRow(
                novel: novel,
                detailStyle: .metrics
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            NovelWaterfallView(
                novels: [
                    Novel(
                        id: 1,
                        title: "测试小说标题",
                        caption: "测试简介",
                        restrict: 0,
                        xRestrict: 0,
                        isOriginal: true,
                        imageUrls: ImageUrls(
                            squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg",
                            medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
                            large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
                        ),
                        createDate: "2023-12-15T00:00:00+09:00",
                        tags: [
                            NovelTag(name: "原创", translatedName: nil, addedByUploadedUser: true),
                            NovelTag(name: "ファンタジー", translatedName: "奇幻", addedByUploadedUser: true)
                        ],
                        pageCount: 1,
                        textLength: 15000,
                        user: User(
                            profileImageUrls: ProfileImageUrls(
                                px50x50: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
                            ),
                            id: StringIntValue.string("1"),
                            name: "测试作者",
                            account: "test_user"
                        ),
                        series: nil,
                        isBookmarked: false,
                        totalBookmarks: 123,
                        totalView: 4567,
                        visible: true,
                        isMuted: false,
                        isMypixivOnly: false,
                        isXRestricted: false,
                        novelAIType: 0
                    )
                ],
                isLoadingMore: false,
                hasReachedEnd: false,
                onLoadMore: {}
            )
        }
    }
}

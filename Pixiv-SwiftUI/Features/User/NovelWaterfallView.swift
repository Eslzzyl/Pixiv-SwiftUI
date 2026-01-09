import SwiftUI

struct NovelWaterfallView: View {
    let novels: [Novel]
    let isLoadingMore: Bool
    let onLoadMore: () -> Void
    @Environment(UserSettingStore.self) var settingStore

    private var filteredNovels: [Novel] {
        var result = novels
        if settingStore.userSetting.r18DisplayMode == 2 {
            result = result.filter { $0.xRestrict < 1 }
        }
        if settingStore.userSetting.blockAI {
            result = result.filter { $0.novelAIType != 2 }
        }
        return result
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredNovels) { novel in
                    NovelRowView(novel: novel)
                }

                if isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.horizontal, 12)
        }
        .onAppear {
            if !filteredNovels.isEmpty {
                onLoadMore()
            }
        }
    }
}

struct NovelRowView: View {
    let novel: Novel

    private func formatTextLength(_ length: Int) -> String {
        if length >= 10000 {
            return String(format: "%.1f万字", Double(length) / 10000)
        } else if length >= 1000 {
            return String(format: "%.1f千字", Double(length) / 1000)
        }
        return "\(length)字"
    }

    var body: some View {
        NavigationLink(value: novel) {
            HStack(alignment: .top, spacing: 12) {
                CachedAsyncImage(
                    urlString: novel.imageUrls.medium,
                    expiration: DefaultCacheExpiration.novel
                )
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(novel.title)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(novel.user.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label(formatTextLength(novel.textLength), systemImage: "text.alignleft")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        HStack(spacing: 2) {
                            Image(systemName: novel.isBookmarked ? "heart.fill" : "heart")
                                .foregroundColor(novel.isBookmarked ? .red : .secondary)
                                .font(.caption2)
                            Text("\(novel.totalBookmarks)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 2) {
                            Image(systemName: "eye")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                            Text("\(novel.totalView)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !novel.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(novel.tags.prefix(5)) { tag in
                                    Text(tag.name)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.gray.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
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
                onLoadMore: {}
            )
        }
    }
}

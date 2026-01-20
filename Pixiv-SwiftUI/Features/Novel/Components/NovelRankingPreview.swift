import SwiftUI

struct NovelRankingPreview: View {
    @ObservedObject var store: NovelStore
    @State private var isLoading = false

    private var novels: [Novel] {
        store.dailyRankingNovels
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                NavigationLink(value: NovelRankingType.daily) {
                    HStack(spacing: 4) {
                        Text("排行")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal)

            if isLoading && novels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<5, id: \.self) { _ in
                            SkeletonNovelCard()
                        }
                    }
                    .padding(.horizontal)
                }
            } else if novels.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无排行数据")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 100)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(novels.prefix(10)) { novel in
                            NavigationLink(value: novel) {
                                NovelRankingCard(novel: novel)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            if novels.isEmpty {
                isLoading = true
            }
        }
        .onChange(of: novels.count) { _, newValue in
            if newValue > 0 {
                isLoading = false
            }
        }
        .task {
            await store.loadDailyRanking()
        }
    }
}

struct NovelRankingCard: View {
    let novel: Novel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CachedAsyncImage(
                urlString: novel.imageUrls.medium,
                expiration: DefaultCacheExpiration.novel
            )
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(novel.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
                .multilineTextAlignment(.leading)

            Text(novel.user.name)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)

            HStack(spacing: 2) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 10))
                Text(formatTextLength(novel.textLength))
                    .font(.caption2)

                Spacer()

                Image(systemName: novel.isBookmarked ? "heart.fill" : "heart")
                    .foregroundColor(novel.isBookmarked ? .red : .secondary)
                    .font(.system(size: 10))
                Text("\(novel.totalBookmarks)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 100)
        }
        .frame(width: 120)
    }

    private func formatTextLength(_ length: Int) -> String {
        if length >= 10000 {
            return String(format: "%.1f万字", Double(length) / 10000)
        } else if length >= 1000 {
            return String(format: "%.1f千字", Double(length) / 1000)
        }
        return "\(length)字"
    }
}

enum NovelRankingType: Hashable, Identifiable {
    case daily
    case dailyMale
    case dailyFemale
    case week

    var id: String {
        switch self {
        case .daily: return "daily"
        case .dailyMale: return "dailyMale"
        case .dailyFemale: return "dailyFemale"
        case .week: return "week"
        }
    }

    var title: String {
        switch self {
        case .daily: return "每日"
        case .dailyMale: return "男性向"
        case .dailyFemale: return "女性向"
        case .week: return "每周"
        }
    }

    var mode: NovelRankingMode {
        switch self {
        case .daily: return .day
        case .dailyMale: return .dayMale
        case .dailyFemale: return .dayFemale
        case .week: return .week
        }
    }
}

#Preview {
    let novels = [
        Novel(
            id: 123,
            title: "示例小说标题",
            caption: "",
            restrict: 0,
            xRestrict: 0,
            isOriginal: true,
            imageUrls: ImageUrls(
                squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg",
                medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
                large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
            ),
            createDate: "2023-12-15T00:00:00+09:00",
            tags: [],
            pageCount: 1,
            textLength: 15000,
            user: User(
                profileImageUrls: ProfileImageUrls(px50x50: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg"),
                id: StringIntValue.string("1"),
                name: "示例作者",
                account: "test_user"
            ),
            series: nil,
            isBookmarked: false,
            totalBookmarks: 1234,
            totalView: 56789,
            visible: true,
            isMuted: false,
            isMypixivOnly: false,
            isXRestricted: false,
            novelAIType: 0
        )
    ]

    let store = NovelStore()
    store.dailyRankingNovels = novels

    return NavigationStack {
        NovelRankingPreview(store: store)
    }
}

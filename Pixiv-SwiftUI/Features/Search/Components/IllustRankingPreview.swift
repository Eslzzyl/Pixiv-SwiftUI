import SwiftUI

struct IllustRankingPreview: View {
    @State private var store = IllustStore()
    @State private var isLoading = false

    private var illusts: [Illusts] {
        store.dailyRankingIllusts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                NavigationLink(value: IllustRankingType.daily) {
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

            if isLoading && illusts.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 140)
            } else if illusts.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无排行数据")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 100)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(illusts.prefix(10)) { illust in
                            NavigationLink(value: illust) {
                                IllustRankingCard(illust: illust)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(.top, 16)
        .onAppear {
            if illusts.isEmpty {
                isLoading = true
            }
        }
        .onChange(of: illusts.count) { _, newValue in
            if newValue > 0 {
                isLoading = false
            }
        }
        .task {
            await store.loadDailyRanking()
        }
    }
}

struct IllustRankingCard: View {
    let illust: Illusts
    @Environment(UserSettingStore.self) var userSettingStore

    private var isR18: Bool {
        return illust.xRestrict >= 1
    }

    private var shouldBlur: Bool {
        return isR18 && userSettingStore.userSetting.r18DisplayMode == 1
    }

    private var shouldHide: Bool {
        let hideR18 = isR18 && userSettingStore.userSetting.r18DisplayMode == 2
        let hideAI = illust.illustAIType == 2 && userSettingStore.userSetting.blockAI
        return hideR18 || hideAI
    }

    var body: some View {
        if shouldHide {
            Color.clear.frame(width: 120, height: 160)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    CachedAsyncImage(
                        urlString: illust.imageUrls.medium,
                        aspectRatio: illust.safeAspectRatio
                    )
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .blur(radius: shouldBlur ? 20 : 0)

                    HStack(spacing: 2) {
                        if illust.type == "ugoira" {
                            Text("动图")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(4)
                        }

                        if illust.pageCount > 1 {
                            Text("\(illust.pageCount)")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(4)
                        }
                    }
                    .padding(4)
                }

                Text(illust.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(width: 100, alignment: .leading)
                    .multilineTextAlignment(.leading)

                Text(illust.user.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 100, alignment: .leading)

                HStack(spacing: 0) {
                    HStack(spacing: 1) {
                        Image(systemName: illust.isBookmarked ? "heart.fill" : "heart")
                            .foregroundColor(illust.isBookmarked ? .red : .secondary)
                            .font(.system(size: 10))
                        Text("\(illust.totalBookmarks)")
                            .font(.caption2)
                    }

                    Spacer()

                    HStack(spacing: 1) {
                        Image(systemName: "eye")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                        Text(formatCount(illust.totalView))
                            .font(.caption2)
                    }
                }
                .frame(width: 100)
            }
            .frame(width: 120)
        }
    }
    private func formatCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1f万", Double(count) / 10000)
        } else if count >= 1000 {
            return String(format: "%.1f千", Double(count) / 1000)
        }
        return "\(count)"
    }
}

enum IllustRankingType: Hashable, Identifiable {
    case daily
    case dailyMale
    case dailyFemale
    case week
    case month

    var id: String {
        switch self {
        case .daily: return "daily"
        case .dailyMale: return "dailyMale"
        case .dailyFemale: return "dailyFemale"
        case .week: return "week"
        case .month: return "month"
        }
    }

    var title: String {
        switch self {
        case .daily: return "每日"
        case .dailyMale: return "男性向"
        case .dailyFemale: return "女性向"
        case .week: return "每周"
        case .month: return "每月"
        }
    }

    var mode: IllustRankingMode {
        switch self {
        case .daily: return .day
        case .dailyMale: return .dayMale
        case .dailyFemale: return .dayFemale
        case .week: return .week
        case .month: return .month
        }
    }
}

#Preview {
    let _ = Illusts(
        id: 123,
        title: "示例插画标题",
        type: "illust",
        imageUrls: ImageUrls(
            squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p0_square1200.jpg",
            medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
            large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
        ),
        caption: "",
        restrict: 0,
        user: User(
            profileImageUrls: ProfileImageUrls(
                px50x50: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
            ),
            id: StringIntValue.string("1"),
            name: "示例作者",
            account: "test_user"
        ),
        tags: [],
        tools: [],
        createDate: "2023-12-15T00:00:00+09:00",
        pageCount: 1,
        width: 900,
        height: 1200,
        sanityLevel: 2,
        xRestrict: 0,
        metaSinglePage: nil,
        metaPages: [],
        totalView: 56789,
        totalBookmarks: 1234,
        isBookmarked: false,
        bookmarkRestrict: nil,
        visible: true,
        isMuted: false,
        illustAIType: 0
    )

    IllustRankingPreview()
}

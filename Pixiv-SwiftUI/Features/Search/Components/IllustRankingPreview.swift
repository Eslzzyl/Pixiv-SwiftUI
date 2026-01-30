import SwiftUI

struct IllustRankingPreview: View {
    @State private var store = IllustStore()
    private let accountStore = AccountStore.shared

    private var illusts: [Illusts] {
        store.dailyRankingIllusts
    }

    private var isGuestMode: Bool {
        !accountStore.isLoggedIn
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isGuestMode {
                    Text("排行")
                        .font(.headline)
                        .foregroundColor(.primary)
                } else {
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
                }
                Spacer()
            }
            .padding(.horizontal)

            if isGuestMode {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("登录后查看排行榜")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 120)
            } else if store.isLoadingRanking && illusts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(0..<6, id: \.self) { _ in
                            SkeletonRankingCard(width: 100, aspectRatio: 1.0, showTitle: true, showSubtitle: true)
                        }
                    }
                    .padding(.horizontal, 2)
                }
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
        let r18Mode = userSettingStore.userSetting.r18DisplayMode
        let aiMode = userSettingStore.userSetting.aiDisplayMode

        let hideR18 = (isR18 && r18Mode == 2) || (!isR18 && r18Mode == 3)
        let hideAI = (illust.illustAIType == 2 && aiMode == 1) || (illust.illustAIType != 2 && aiMode == 2)

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
    IllustRankingPreview()
}

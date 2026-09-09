import SwiftUI

struct IllustRankingPreview: View {
    private let store = IllustStore.shared
    private let accountStore = AccountStore.shared
    @Environment(UserSettingStore.self) var userSettingStore

    private var preferredMode: IllustRankingMode {
        userSettingStore.enabledIllustRankingModes.first ?? .day
    }

    private var illusts: [Illusts] {
        store.illusts(for: preferredMode)
    }

    private var displayedIllusts: [Illusts] {
        Array(illusts.prefix(10))
    }

    private var isGuestMode: Bool {
        !accountStore.isLoggedIn
    }

    private var rankingType: IllustRankingType? {
        IllustRankingType(mode: preferredMode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isGuestMode {
                    Text("排行")
                        .font(.headline)
                        .foregroundColor(.primary)
                } else if let rankingType = rankingType {
                    NavigationLink(value: PixivNavigationRoute.illustRanking(rankingType)) {
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
                } else {
                    Text("排行")
                        .font(.headline)
                        .foregroundColor(.primary)
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
                    HStack(spacing: 12) {
                        ForEach(0..<6, id: \.self) { _ in
                            SkeletonIllustRankingCard(width: 140)
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.25)))
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
                    HStack(spacing: 12) {
                        ForEach(displayedIllusts) { illust in
                            IllustDetailNavigationLink(illust: illust, context: displayedIllusts) {
                                IllustRankingCard(illust: illust)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            }
        }
        .padding(.top, 16)
        .task {
            await store.loadRanking(mode: preferredMode)
        }
    }
}

struct IllustRankingCard: View {
    let illust: Illusts
    @Environment(UserSettingStore.self) var userSettingStore

    private var isR18: Bool {
        return illust.xRestrict == 1
    }

    private var isR18G: Bool {
        return illust.xRestrict == 2
    }

    private var isSpoiler: Bool {
        return illust.isSpoiler
    }

    private var shouldBlur: Bool {
        if isR18 && userSettingStore.userSetting.r18DisplayMode == 1 { return true }
        if isR18G && userSettingStore.userSetting.r18gDisplayMode == 1 { return true }
        if isSpoiler && userSettingStore.userSetting.spoilerDisplayMode == 1 { return true }
        return false
    }

    private var shouldHide: Bool {
        let r18Mode = userSettingStore.userSetting.r18DisplayMode
        let r18gMode = userSettingStore.userSetting.r18gDisplayMode
        let spoilerMode = userSettingStore.userSetting.spoilerDisplayMode
        let aiMode = userSettingStore.userSetting.aiDisplayMode

        let hideR18 = (isR18 && r18Mode == 2) || (!isR18 && r18Mode == 3)
        let hideR18G = (isR18G && r18gMode == 2) || (!isR18G && r18gMode == 3)
        let hideSpoiler = (isSpoiler && spoilerMode == 2) || (!isSpoiler && spoilerMode == 3)
        let hideAI = (illust.illustAIType == 2 && aiMode == 1) || (illust.illustAIType != 2 && aiMode == 2)

        return hideR18 || hideR18G || hideSpoiler || hideAI
    }

    private let imageHeight: CGFloat = 140
    private let cardWidth: CGFloat = 140

    var body: some View {
        if shouldHide {
            Color.clear
                .frame(width: cardWidth, height: imageHeight + 70)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                CachedAsyncImage(
                    urlString: illust.imageUrls.medium,
                    aspectRatio: illust.safeAspectRatio
                )
                .frame(width: cardWidth, height: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .blur(radius: shouldBlur ? 20 : 0)
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 4) {
                        if illust.type == "manga" {
                            Text("漫画")
                                .badgeStyle()
                        }

                        if illust.type == "ugoira" {
                            Text("动图")
                                .badgeStyle()
                        }

                        if illust.illustAIType == 2 {
                            Text("AI")
                                .badgeStyle()
                        }
                    }
                    .padding(6)
                }
                .overlay(alignment: .topTrailing) {
                    if illust.pageCount > 1 {
                        Text("\(illust.pageCount)")
                            .badgeStyle()
                            .padding(6)
                    }
                }

                Text(illust.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(illust.user.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                .frame(maxWidth: .infinity)
            }
            .frame(width: cardWidth)
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
    case weekOriginal
    case weekRookie
    case dayAI
    case dayR18AI
    case dayR18
    case weekR18
    case weekR18G

    static var defaultTypes: [IllustRankingType] {
        [.daily, .dailyMale, .dailyFemale, .week, .month]
    }

    init?(mode: IllustRankingMode) {
        switch mode {
        case .day:
            self = .daily
        case .dayMale:
            self = .dailyMale
        case .dayFemale:
            self = .dailyFemale
        case .week:
            self = .week
        case .month:
            self = .month
        case .weekOriginal:
            self = .weekOriginal
        case .weekRookie:
            self = .weekRookie
        case .dayAI:
            self = .dayAI
        case .dayR18AI:
            self = .dayR18AI
        case .dayR18:
            self = .dayR18
        case .weekR18:
            self = .weekR18
        case .weekR18G:
            self = .weekR18G
        }
    }

    var id: String {
        switch self {
        case .daily: return "daily"
        case .dailyMale: return "dailyMale"
        case .dailyFemale: return "dailyFemale"
        case .week: return "week"
        case .month: return "month"
        case .weekOriginal: return "weekOriginal"
        case .weekRookie: return "weekRookie"
        case .dayAI: return "dayAI"
        case .dayR18AI: return "dayR18AI"
        case .dayR18: return "dayR18"
        case .weekR18: return "weekR18"
        case .weekR18G: return "weekR18G"
        }
    }

    var title: String {
        mode.title
    }

    var mode: IllustRankingMode {
        switch self {
        case .daily: return .day
        case .dailyMale: return .dayMale
        case .dailyFemale: return .dayFemale
        case .week: return .week
        case .month: return .month
        case .weekOriginal: return .weekOriginal
        case .weekRookie: return .weekRookie
        case .dayAI: return .dayAI
        case .dayR18AI: return .dayR18AI
        case .dayR18: return .dayR18
        case .weekR18: return .weekR18
        case .weekR18G: return .weekR18G
        }
    }
}

#Preview {
    IllustRankingPreview()
}

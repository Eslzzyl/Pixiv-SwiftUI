import SwiftUI
import os.log

struct IllustDetailInfoSection: View {
    let illust: Illusts
    let userSettingStore: UserSettingStore
    let accountStore: AccountStore
    let colorScheme: ColorScheme
    let authorLatestIllusts: [Illusts]
    let isLoadingAuthorLatestIllusts: Bool
    let onFetchAuthorLatestIllusts: () -> Void

    @Binding var isFollowed: Bool
    @Binding var isBookmarked: Bool
    @Binding var totalComments: Int?
    @Binding var isBlockTriggered: Bool
    @Binding var isCommentsPanelPresented: Bool

    @Environment(ThemeManager.self) var themeManager

    private var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            IllustDetailTitleView(illust: illust)

            IllustDetailAuthorSection(
                illust: illust,
                accountStore: accountStore,
                themeManager: themeManager,
                isFollowed: $isFollowed,
                onFetchAuthorLatestIllusts: onFetchAuthorLatestIllusts
            )
            .padding(.vertical, -4)

            if isLoggedIn {
                IllustDetailActionButtons(
                    illust: illust,
                    userSettingStore: userSettingStore,
                    accountStore: accountStore,
                    themeManager: themeManager,
                    colorScheme: colorScheme,
                    isBookmarked: $isBookmarked,
                    totalComments: $totalComments,
                    isCommentsPanelPresented: $isCommentsPanelPresented
                )
            }

            IllustDetailMetadataSection(illust: illust, isBookmarked: $isBookmarked)

            Divider()

            IllustDetailTagsSection(
                illust: illust,
                userSettingStore: userSettingStore,
                accountStore: accountStore
            )

            IllustDetailCaptionSection(illust: illust)

            IllustDetailAuthorLatestWorksSection(
                illust: illust,
                illusts: authorLatestIllusts,
                isLoading: isLoadingAuthorLatestIllusts
            )
        }
    }

}

private struct IllustDetailMetadataSection: View {
    let illust: Illusts
    @Binding var isBookmarked: Bool
    @Environment(ThemeManager.self) private var themeManager
    @Environment(ToastPresenter.self) private var toast
    private var bookmarkIconName: String {
        if !isBookmarked {
            return "heart"
        }
        return illust.bookmarkRestrict == "private" ? "heart.slash.fill" : "heart.fill"
    }

    var body: some View {
        metadataRow
    }
    private var isAI: Bool {
        illust.illustAIType == 2
    }

    private var metadataRow: some View {
        FlowLayout(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "number")
                    .font(.caption2)
                Text(String(illust.id))
                    .font(.caption)
                    .textSelection(.enabled)

                Button(action: {
                    copyToClipboard(String(illust.id))
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.caption2)
                Text(NumberFormatter.formatCount(illust.totalView))
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: bookmarkIconName)
                    .font(.caption2)
                Text(NumberFormatter.formatCount(illust.totalBookmarks))
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text(formatDateTime(illust.createDate))
                    .font(.caption)
            }

            if isAI {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("AI")
                        .font(.caption)
                }
            }

            if let series = illust.series {
                NavigationLink(value: PixivNavigationRoute.illustSeries(id: series.id)) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.stack.fill")
                            .foregroundColor(themeManager.currentColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("所属系列")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(series.title ?? String(localized: "系列"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(themeManager.currentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            #if os(macOS)
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption2)
                Text("\(illust.width) x \(illust.height)")
                    .font(.caption)
            }

            if !illust.tools.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "paintbrush")
                        .font(.caption2)
                    Text(illust.tools.joined(separator: ", "))
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            #endif
        }
        .foregroundColor(.secondary)
    }

    private func formatDateTime(_ dateString: String) -> String {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        if let parsedDate = formatter.date(from: dateString) {
            let displayFormatter = Foundation.DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return displayFormatter.string(from: parsedDate)
        }

        return dateString
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #else
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(text, forType: .string)
        #endif
        toast.show(String(localized: "已复制"))
    }
}

private struct IllustDetailTitleView: View {
    let illust: Illusts

    var body: some View {
        TranslatableText(text: illust.title, font: .title2)
            .fontWeight(.bold)
            .padding(.top, 2)
    }
}

private struct IllustDetailAuthorSection: View {
    let illust: Illusts
    let accountStore: AccountStore
    let themeManager: ThemeManager
    @Binding var isFollowed: Bool
    let onFetchAuthorLatestIllusts: () -> Void
    @State private var isFollowLoading = false
    @Environment(ToastPresenter.self) private var toast

    private var isLoggedIn: Bool { accountStore.isLoggedIn }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isLoggedIn {
                    NavigationLink(value: PixivNavigationRoute.user(id: illust.user.id.stringValue)) {
                        authorInfo
                    }
                } else {
                    authorInfo
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if isLoggedIn {
                Button(action: toggleFollow) {
                    ZStack {
                        Text(isFollowed ? String(localized: "取消关注") : String(localized: "关注"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .frame(minWidth: 70)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .opacity(isFollowLoading ? 0 : 1)

                        if isFollowLoading {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .buttonStyle(GlassButtonStyle(color: isFollowed ? nil : themeManager.currentColor))
                .disabled(isFollowLoading)
                .sensoryFeedback(.impact(weight: .medium), trigger: isFollowed)
            }
        }
        .padding(.vertical, 4)
        .task { onFetchAuthorLatestIllusts() }
        .task {
            if isLoggedIn && illust.user.isFollowed == nil {
                do {
                    let detail = try await PixivAPI.shared.userAPI.getUserDetail(userId: illust.user.id.stringValue)
                    illust.user.isFollowed = detail.user.isFollowed
                } catch {
                    Logger.general.error("Failed to fetch user detail: \(error)")
                }
            }
        }
    }

    private var authorInfo: some View {
        HStack(spacing: 12) {
            AnimatedAvatarImage(
                urlString: illust.user.profileImageUrls?.px50x50 ?? illust.user.profileImageUrls?.medium,
                size: 48,
                expiration: DefaultCacheExpiration.userAvatar
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(illust.user.name).font(.headline)
                Text("@\(illust.user.account)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func toggleFollow() {
        guard isLoggedIn else {
            toast.show(String(localized: "请先登录"), duration: 2.0)
            return
        }
        let requestGeneration = accountStore.accountGeneration
        let requestUserId = accountStore.currentUserId
        Task {
            isFollowLoading = true
            defer { isFollowLoading = false }
            let userId = illust.user.id.stringValue
            do {
                if isFollowed {
                    try await PixivAPI.shared.userAPI.unfollowUser(userId: userId)
                    guard accountStore.isCurrentAccount(generation: requestGeneration, userId: requestUserId) else { return }
                    isFollowed = false
                    illust.user.isFollowed = false
                } else {
                    try await PixivAPI.shared.userAPI.followUser(userId: userId)
                    guard accountStore.isCurrentAccount(generation: requestGeneration, userId: requestUserId) else { return }
                    isFollowed = true
                    illust.user.isFollowed = true
                }
            } catch {
                Logger.general.error("Follow toggle failed: \(error)")
            }
        }
    }
}

private struct IllustDetailActionButtons: View {
    let illust: Illusts
    let userSettingStore: UserSettingStore
    let accountStore: AccountStore
    let themeManager: ThemeManager
    let colorScheme: ColorScheme
    @Binding var isBookmarked: Bool
    @Binding var totalComments: Int?
    @Binding var isCommentsPanelPresented: Bool
    @Environment(ToastPresenter.self) private var toast

    private var bookmarkIconName: String {
        if !isBookmarked { return "heart" }
        return illust.bookmarkRestrict == "private" ? "heart.slash.fill" : "heart.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            #if os(iOS)
            Button(action: { isCommentsPanelPresented = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text(String(localized: "查看评论"))
                    if let totalComments, totalComments > 0 {
                        Text("(\(totalComments))").foregroundColor(.secondary)
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background { Capsule().fill(Color.secondary.opacity(colorScheme == .dark ? 0.18 : 0.08)) }
            }
            .buttonStyle(.plain)
            #endif

            Button(action: {
                if isBookmarked {
                    bookmarkIllust(forceUnbookmark: true)
                } else {
                    bookmarkIllust(isPrivate: userSettingStore.userSetting.defaultPrivateLike)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: bookmarkIconName)
                    Text(isBookmarked ? String(localized: "取消收藏") : String(localized: "收藏"))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isBookmarked ? themeManager.currentColor : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if isBookmarked {
                        Capsule()
                            .fill(themeManager.currentColor.opacity(colorScheme == .dark ? 0.22 : 0.12))
                            .overlay(Capsule().strokeBorder(themeManager.currentColor.opacity(0.28), lineWidth: 1))
                    } else {
                        Capsule().fill(themeManager.currentColor)
                            .shadow(color: themeManager.currentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: isBookmarked)
            .contextMenu {
                if isBookmarked {
                    if illust.bookmarkRestrict == "private" {
                        Button(action: { bookmarkIllust(isPrivate: false) }) {
                            Label(String(localized: "切换为公开收藏"), systemImage: "heart")
                        }
                    } else {
                        Button(action: { bookmarkIllust(isPrivate: true) }) {
                            Label(String(localized: "切换为非公开收藏"), systemImage: "heart.slash")
                        }
                    }
                    Button(role: .destructive, action: { bookmarkIllust(forceUnbookmark: true) }) {
                        Label(String(localized: "取消收藏"), systemImage: "heart.slash")
                    }
                } else {
                    Button(action: { bookmarkIllust(isPrivate: false) }) {
                        Label(String(localized: "公开收藏"), systemImage: "heart")
                    }
                    Button(action: { bookmarkIllust(isPrivate: true) }) {
                        Label(String(localized: "非公开收藏"), systemImage: "heart.slash")
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func bookmarkIllust(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
        guard accountStore.isLoggedIn else {
            toast.show(String(localized: "请先登录"), duration: 2.0)
            return
        }
        let requestGeneration = accountStore.accountGeneration
        let requestUserId = accountStore.currentUserId
        Task {
            await BookmarkActionService.shared.toggleBookmark(
                illust: illust,
                isPrivate: isPrivate,
                forceUnbookmark: forceUnbookmark
            )
            guard accountStore.isCurrentAccount(generation: requestGeneration, userId: requestUserId) else { return }
            isBookmarked = illust.isBookmarked
        }
    }
}

private struct IllustDetailTagsSection: View {
    let illust: Illusts
    let userSettingStore: UserSettingStore
    let accountStore: AccountStore
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastPresenter.self) private var toast

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "标签"))
                .font(.headline)
                .foregroundColor(.secondary)
            FlowLayout(spacing: 6, reorderToFill: userSettingStore.userSetting.tagLayoutOptimizationEnabled) {
                ForEach(illust.tags, id: \.name) { tag in
                    Group {
                        if accountStore.isLoggedIn {
                            NavigationLink(value: PixivNavigationRoute.search(SearchResultTarget(word: tag.name))) {
                                TagChip(tag: tag)
                            }
                        } else {
                            TagChip(tag: tag)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(action: { copyToClipboard(tag.name) }) {
                            Label(String(localized: "复制 tag"), systemImage: "doc.on.doc")
                        }
                        if accountStore.isLoggedIn {
                            Button(action: {
                                try? userSettingStore.addBlockedTagWithInfo(tag.name, translatedName: tag.translatedName)
                                toast.show(String(localized: "已屏蔽 Tag"))
                                dismiss()
                            }) {
                                Label(String(localized: "屏蔽 tag"), systemImage: "eye.slash")
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #else
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(text, forType: .string)
        #endif
        toast.show(String(localized: "已复制"))
    }
}

private struct IllustDetailCaptionSection: View {
    let illust: Illusts

    var body: some View {
        if !illust.caption.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "简介"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                TranslatableText(text: illust.caption, font: .body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct IllustDetailAuthorLatestWorksSection: View {
    let illust: Illusts
    let illusts: [Illusts]
    let isLoading: Bool

    @Environment(UserSettingStore.self) private var settingStore
    @ScaledMetric(relativeTo: .body) private var thumbnailSize = 88.0

    private var visibleIllusts: [Illusts] {
        Array(settingStore.filterIllusts(illusts).prefix(4))
    }

    var body: some View {
        if isLoading && illusts.isEmpty || !visibleIllusts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.bottom, 8)

                Text("作者最新作品")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if isLoading && illusts.isEmpty {
                    loadingWorksView
                } else {
                    worksScrollView
                }
            }
        }
    }

    private var loadingWorksView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.quaternary)
                        .frame(width: thumbnailSize, height: thumbnailSize)
                        .redacted(reason: .placeholder)
                }
            }
        }
    }

    private var worksScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(visibleIllusts) { illust in
                    IllustDetailNavigationLink(
                        illust: illust,
                        context: visibleIllusts
                    ) {
                        IllustDetailAuthorLatestWorksThumbnail(
                            illust: illust,
                            size: thumbnailSize
                        )
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink(value: PixivNavigationRoute.user(id: illust.user.id.stringValue)) {
                    IllustDetailAuthorLatestWorksMoreButton(size: thumbnailSize)
                }
                .buttonStyle(.plain)
            }
        }
        .illustDetailNavigationSourceScope()
    }
}

private struct IllustDetailAuthorLatestWorksThumbnail: View {
    let illust: Illusts
    let size: CGFloat

    private var thumbnailURL: String {
        illust.imageUrls.squareMedium.isEmpty
            ? illust.imageUrls.medium
            : illust.imageUrls.squareMedium
    }

    var body: some View {
        CachedAsyncImage(
            urlString: thumbnailURL,
            aspectRatio: 1,
            idealWidth: size,
            expiration: DefaultCacheExpiration.illustDetail
        )
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: 10))
        .contentShape(Rectangle())
        .accessibilityLabel(illust.title)
    }
}

private struct IllustDetailAuthorLatestWorksMoreButton: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary)

            VStack(spacing: 6) {
                Image(systemName: "ellipsis")
                    .font(.headline)

                Text("查看更多")
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .accessibilityLabel("查看更多")
    }
}

#Preview("作者最新作品") {
    NavigationStack {
        IllustDetailAuthorLatestWorksSection(
            illust: IllustDetailPreviewData.illust,
            illusts: [],
            isLoading: true
        )
        .padding()
    }
    .environment(UserSettingStore.shared)
}

#Preview("标题") {
    IllustDetailTitleView(illust: IllustDetailPreviewData.illust)
        .padding()
}

#Preview("简介") {
    IllustDetailCaptionSection(illust: IllustDetailPreviewData.illust)
        .padding()
}

private enum IllustDetailPreviewData {
    static var illust: Illusts {
        let user = User(id: .string("1"), name: "Preview author", account: "preview")
        user.isFollowed = false
        return Illusts(
            id: 1,
            title: "Preview illustration",
            type: "illust",
            imageUrls: ImageUrls(squareMedium: "", medium: "", large: ""),
            caption: "Preview caption",
            restrict: 0,
            user: user,
            tags: [],
            tools: [],
            createDate: "",
            pageCount: 1,
            width: 900,
            height: 1200,
            sanityLevel: 2,
            xRestrict: 0,
            metaSinglePage: nil,
            metaPages: [],
            totalView: 100,
            totalBookmarks: 10,
            isBookmarked: false,
            bookmarkRestrict: nil,
            visible: true,
            isMuted: false,
            illustAIType: 0
        )
    }
}

#Preview("Detail information") {
    let settings = UserSettingStore()
    return IllustDetailInfoSection(
        illust: IllustDetailPreviewData.illust,
        userSettingStore: settings,
        accountStore: AccountStore.shared,
        colorScheme: .light,
        authorLatestIllusts: [],
        isLoadingAuthorLatestIllusts: false,
        onFetchAuthorLatestIllusts: {},
        isFollowed: .constant(false),
        isBookmarked: .constant(false),
        totalComments: .constant(2),
        isBlockTriggered: .constant(false),
        isCommentsPanelPresented: .constant(false)
    )
    .environment(settings)
    .environment(ThemeManager(userSettingStore: settings))
    .environment(ToastPresenter())
    .padding()
}

#Preview("Detail metadata") {
    IllustDetailMetadataSection(illust: IllustDetailPreviewData.illust, isBookmarked: .constant(false))
        .environment(ThemeManager(userSettingStore: UserSettingStore()))
        .environment(ToastPresenter())
        .padding()
}

#Preview("Detail author") {
    IllustDetailAuthorSection(
        illust: IllustDetailPreviewData.illust,
        accountStore: AccountStore.shared,
        themeManager: ThemeManager(userSettingStore: UserSettingStore()),
        isFollowed: .constant(false),
        onFetchAuthorLatestIllusts: {}
    )
    .environment(ToastPresenter())
    .padding()
}

#Preview("Detail actions") {
    let settings = UserSettingStore()
    return IllustDetailActionButtons(
        illust: IllustDetailPreviewData.illust,
        userSettingStore: settings,
        accountStore: AccountStore.shared,
        themeManager: ThemeManager(userSettingStore: settings),
        colorScheme: .light,
        isBookmarked: .constant(false),
        totalComments: .constant(2),
        isCommentsPanelPresented: .constant(false)
    )
    .environment(ToastPresenter())
    .padding()
}

#Preview("Detail tags") {
    IllustDetailTagsSection(
        illust: IllustDetailPreviewData.illust,
        userSettingStore: UserSettingStore(),
        accountStore: AccountStore.shared
    )
    .environment(ToastPresenter())
    .padding()
}

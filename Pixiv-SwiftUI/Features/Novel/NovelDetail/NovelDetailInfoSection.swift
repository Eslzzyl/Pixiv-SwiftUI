import SwiftUI
import TranslationKit

struct NovelDetailInfoSection: View {
    let novel: Novel
    let userSettingStore: UserSettingStore
    let accountStore: AccountStore
    let colorScheme: ColorScheme

    @Binding var isBookmarked: Bool
    @Binding var isFollowed: Bool?
    @Binding var totalComments: Int?
    @Binding var showNotLoggedInToast: Bool
    @Binding var showBlockTagToast: Bool
    @Binding var showCopyToast: Bool
    @Binding var navigateToUserId: String?
    @Binding var isCommentsPanelPresented: Bool

    @State private var isFollowLoading = false

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) var themeManager

    private var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    private var bookmarkIconName: String {
        isBookmarked ? "heart.fill" : "heart"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleSection

            authorSection
                .padding(.vertical, -4)

            if isLoggedIn {
                actionButtons
            }

            metadataRow

            Divider()

            tagsSection

            Divider()

            if let series = novel.series {
                seriesSection(series)
            }

            if !novel.caption.isEmpty {
                captionSection
            }

        }
    }

    private var titleSection: some View {
        TranslatableText(text: novel.title, font: .title2)
            .fontWeight(.bold)
    }

    private var authorSection: some View {
        HStack(spacing: 12) {
            Group {
                if isLoggedIn {
                    NavigationLink(value: novel.user) {
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
                        Text(isFollowed == true ? String(localized: "已关注") : String(localized: "关注"))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .frame(minWidth: 80)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .opacity(isFollowLoading ? 0 : 1)

                        if isFollowLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .buttonStyle(GlassButtonStyle(color: isFollowed == true ? nil : themeManager.currentColor))
                .disabled(isFollowLoading || isFollowed == nil)
                .sensoryFeedback(.impact(weight: .medium), trigger: isFollowed)
            }
        }
        .padding(.vertical, 8)
        .task {
            if isLoggedIn && isFollowed == nil {
                do {
                    let detail = try await PixivAPI.shared.getUserDetail(userId: novel.user.id.stringValue)
                    isFollowed = detail.user.isFollowed
                } catch {
                    print("Failed to fetch user detail: \(error)")
                }
            }
        }
    }

    private var authorInfo: some View {
        HStack(spacing: 12) {
            AnimatedAvatarImage(
                urlString: novel.user.profileImageUrls?.px50x50
                    ?? novel.user.profileImageUrls?.medium,
                size: 48,
                expiration: DefaultCacheExpiration.userAvatar
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(novel.user.name)
                    .font(.headline)

                Text("@\(novel.user.account)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            #if os(iOS)
            Button(action: { isCommentsPanelPresented = true }) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text(String(localized: "查看评论"))
                    if let totalComments = totalComments, totalComments > 0 {
                        Text("(\(totalComments))")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            #endif

            Button(action: {
                if isBookmarked {
                    toggleBookmark(forceUnbookmark: true)
                } else {
                    toggleBookmark(isPrivate: userSettingStore.userSetting.defaultPrivateLike)
                }
            }) {
                HStack {
                    Image(systemName: bookmarkIconName)
                        .foregroundColor(isBookmarked ? .red : .primary)
                    Text(isBookmarked ? String(localized: "已收藏") : String(localized: "收藏"))
                        .foregroundColor(isBookmarked ? .red : .primary)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: isBookmarked)
            .contextMenu {
                if isBookmarked {
                    if novel.bookmarkRestrict == "private" {
                        Button(action: { toggleBookmark(isPrivate: false) }) {
                            Label(String(localized: "切换为公开收藏"), systemImage: "heart")
                        }
                    } else {
                        Button(action: { toggleBookmark(isPrivate: true) }) {
                            Label(String(localized: "切换为私密收藏"), systemImage: "heart.slash")
                        }
                    }
                    Button(role: .destructive, action: { toggleBookmark(forceUnbookmark: true) }) {
                        Label(String(localized: "取消收藏"), systemImage: "heart.slash")
                    }
                } else {
                    Button(action: { toggleBookmark(isPrivate: userSettingStore.userSetting.defaultPrivateLike) }) {
                        Label(String(localized: "公开收藏"), systemImage: "heart")
                    }
                    Button(action: { toggleBookmark(isPrivate: !userSettingStore.userSetting.defaultPrivateLike) }) {
                        Label(String(localized: "私密收藏"), systemImage: "heart.slash")
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var isAI: Bool {
        novel.novelAIType == 2
    }

    private var metadataRow: some View {
        FlowLayout(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "number")
                    .font(.caption2)
                Text(String(novel.id))
                    .font(.caption)
                    .textSelection(.enabled)

                Button(action: {
                    copyToClipboard(String(novel.id))
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 4) {
                Image(systemName: "text.alignleft")
                    .font(.caption2)
                Text(formatTextLength(novel.textLength))
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.caption2)
                Text(NumberFormatter.formatCount(novel.totalView))
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                Text(NumberFormatter.formatCount(novel.totalBookmarks))
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text(formatDateTime(novel.createDate))
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
        }
        .foregroundColor(.secondary)
    }

    @ViewBuilder
    private func seriesSection(_ series: NovelSeries) -> some View {
        if series.id != nil {
            NavigationLink(value: series) {
                HStack(spacing: 8) {
                    Image(systemName: "books.vertical.fill")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("所属系列")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let title = series.title {
                            Text(title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("简介")
                .font(.headline)
                .foregroundColor(.secondary)

            TranslatableText(text: novel.caption, font: .body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func formatTextLength(_ length: Int) -> String {
        if length >= 10000 {
            return String(format: "%.1f万字", Double(length) / 10000)
        } else if length >= 1000 {
            return String(format: "%.1f千字", Double(length) / 1000)
        }
        return "\(length)字"
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

    private func toggleFollow() {
        guard isFollowed != nil else { return }

        Task {
            isFollowLoading = true
            defer { isFollowLoading = false }

            let userId = novel.user.id.stringValue

            do {
                if isFollowed == true {
                    try await PixivAPI.shared.unfollowUser(userId: userId)
                    isFollowed = false
                } else {
                    try await PixivAPI.shared.followUser(userId: userId)
                    isFollowed = true
                }
            } catch {
                print("Follow toggle failed: \(error)")
            }
        }
    }

    private func toggleBookmark(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
        guard isLoggedIn else {
            showNotLoggedInToast = true
            return
        }

        let wasBookmarked = isBookmarked
        let novelId = novel.id

        if forceUnbookmark && wasBookmarked {
            isBookmarked = false
        } else if wasBookmarked {
            isBookmarked = isBookmarked
        } else {
            isBookmarked = true
        }

        Task {
            do {
                if forceUnbookmark && wasBookmarked {
                    try await PixivAPI.shared.novelAPI?.unbookmarkNovel(novelId: novelId)
                } else if wasBookmarked {
                    try await PixivAPI.shared.novelAPI?.unbookmarkNovel(novelId: novelId)
                    try await PixivAPI.shared.novelAPI?.bookmarkNovel(novelId: novelId, restrict: isPrivate ? "private" : "public")
                } else {
                    try await PixivAPI.shared.novelAPI?.bookmarkNovel(novelId: novelId, restrict: isPrivate ? "private" : "public")
                }
            } catch {
                await MainActor.run {
                    if forceUnbookmark && wasBookmarked {
                        isBookmarked = true
                    } else if wasBookmarked {
                        isBookmarked = true
                    } else {
                        isBookmarked = false
                    }
                }
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "标签"))
                .font(.headline)
                .foregroundColor(.secondary)

            FlowLayout(spacing: 6) {
                ForEach(novel.tags, id: \.name) { tag in
                    Group {
                        if isLoggedIn {
                            NavigationLink(value: SearchResultTarget(word: tag.name)) {
                                TagChip(tag: tag)
                            }
                        } else {
                            TagChip(tag: tag)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(action: {
                            copyToClipboard(tag.name)
                        }) {
                            Label(String(localized: "复制 tag"), systemImage: "doc.on.doc")
                        }

                        if isLoggedIn {
                            Button(action: {
                                try? userSettingStore.addBlockedTagWithInfo(tag.name, translatedName: tag.translatedName)
                                showBlockTagToast = true
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
        showCopyToast = true
    }
}

#Preview {
    NovelDetailInfoSection(
        novel: Novel(
            id: 123,
            title: "示例小说标题",
            caption: "这是一段小说简介，可以包含 HTML 标签。",
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
                NovelTag(name: "ファンタジー", translatedName: "奇幻", addedByUploadedUser: true),
                NovelTag(name: "長編", translatedName: "长篇", addedByUploadedUser: false)
            ],
            pageCount: 1,
            textLength: 15000,
            user: User(
                profileImageUrls: ProfileImageUrls(
                    px50x50: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
                ),
                id: StringIntValue.string("1"),
                name: "示例作者",
                account: "test_user"
            ),
            series: nil,
            isBookmarked: false,
            bookmarkRestrict: nil,
            totalBookmarks: 1234,
            totalView: 56789,
            visible: true,
            isMuted: false,
            isMypixivOnly: false,
            isXRestricted: false,
            novelAIType: 0
        ),
        userSettingStore: .shared,
        accountStore: .shared,
        colorScheme: .light,
        isBookmarked: .constant(false),
        isFollowed: .constant(nil),
        totalComments: .constant(5),
        showNotLoggedInToast: .constant(false),
        showBlockTagToast: .constant(false),
        showCopyToast: .constant(false),
        navigateToUserId: .constant(nil),
        isCommentsPanelPresented: .constant(false)
    )
}

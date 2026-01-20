import SwiftUI
import TranslationKit

struct IllustDetailInfoSection: View {
    let illust: Illusts
    let userSettingStore: UserSettingStore
    let accountStore: AccountStore
    let colorScheme: ColorScheme

    @Binding var isFollowed: Bool
    @Binding var isBookmarked: Bool
    @Binding var totalComments: Int?
    @Binding var showNotLoggedInToast: Bool
    @Binding var showCopyToast: Bool
    @Binding var showBlockTagToast: Bool
    @Binding var isBlockTriggered: Bool
    @Binding var isCommentsPanelPresented: Bool
    @Binding var navigateToUserId: String?

    @State private var isCommentsExpanded = false

    @Environment(\.dismiss) private var dismiss

    @State private var isFollowLoading = false

    private var bookmarkIconName: String {
        if !isBookmarked {
            return "heart"
        }
        return illust.bookmarkRestrict == "private" ? "heart.slash.fill" : "heart.fill"
    }

    private var isLoggedIn: Bool {
        accountStore.isLoggedIn
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

            if !illust.caption.isEmpty {
                Divider()
                captionSection
            }

            #if os(macOS)
            if isCommentsExpanded {
                Divider()

                commentsPanelSection
            }
            #endif
        }
    }

    private var titleSection: some View {
        TranslatableText(text: illust.title, font: .title2)
            .fontWeight(.bold)
    }

    private var metadataRow: some View {
        FlowLayout(spacing: 12) {
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

    private var authorSection: some View {
        HStack(spacing: 12) {
            Group {
                if isLoggedIn {
                    NavigationLink(value: illust.user) {
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
                        Text(isFollowed ? "已关注" : "关注")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .frame(width: 95)
                            .opacity(isFollowLoading ? 0 : 1)

                        if isFollowLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .buttonStyle(GlassButtonStyle(color: isFollowed ? nil : .blue))
                .disabled(isFollowLoading)
                .sensoryFeedback(.impact(weight: .medium), trigger: isFollowed)
            }
        }
        .padding(.vertical, 8)
        .task {
            if isLoggedIn && illust.user.isFollowed == nil {
                do {
                    let detail = try await PixivAPI.shared.getUserDetail(userId: illust.user.id.stringValue)
                    illust.user.isFollowed = detail.user.isFollowed
                } catch {
                    print("Failed to fetch user detail: \(error)")
                }
            }
        }
    }

    private var authorInfo: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(
                urlString: illust.user.profileImageUrls?.px50x50
                    ?? illust.user.profileImageUrls?.medium,
                expiration: DefaultCacheExpiration.userAvatar
            )
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(illust.user.name)
                    .font(.headline)

                Text("@\(illust.user.account)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            #if os(macOS)
            Button(action: { withAnimation { isCommentsExpanded.toggle() } }) {
                HStack {
                    Image(systemName: isCommentsExpanded ? "chevron.up" : "bubble.left.and.bubble.right")
                    Text(isCommentsExpanded ? "收起评论" : "查看评论")
                    if let totalComments = totalComments, totalComments > 0 {
                        Text("(\(totalComments))")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isCommentsExpanded ? Color.blue.opacity(0.2) : Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            #else
            Button(action: { isCommentsPanelPresented = true }) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("查看评论")
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
                    bookmarkIllust(forceUnbookmark: true)
                } else {
                    bookmarkIllust(isPrivate: false)
                }
            }) {
                HStack {
                    Image(systemName: bookmarkIconName)
                        .foregroundColor(isBookmarked ? .red : .primary)
                    Text(isBookmarked ? "已收藏" : "收藏")
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
                    if illust.bookmarkRestrict == "private" {
                        Button(action: { bookmarkIllust(isPrivate: false) }) {
                            Label("切换为公开收藏", systemImage: "heart")
                        }
                    } else {
                        Button(action: { bookmarkIllust(isPrivate: true) }) {
                            Label("切换为非公开收藏", systemImage: "heart.slash")
                        }
                    }
                    Button(role: .destructive, action: { bookmarkIllust(forceUnbookmark: true) }) {
                        Label("取消收藏", systemImage: "heart.slash")
                    }
                } else {
                    Button(action: { bookmarkIllust(isPrivate: false) }) {
                        Label("公开收藏", systemImage: "heart")
                    }
                    Button(action: { bookmarkIllust(isPrivate: true) }) {
                        Label("非公开收藏", systemImage: "heart.slash")
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    #if os(macOS)
    private var commentsPanelSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommentsPanelInlineView(
                illust: illust,
                onUserTapped: { userId in
                    navigateToUserId = userId
                }
            )
        }
    }
    #endif

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签")
                .font(.headline)
                .foregroundColor(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(illust.tags, id: \.name) { tag in
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
                            Label("复制 tag", systemImage: "doc.on.doc")
                        }

                        if isLoggedIn {
                            Button(action: {
                                try? userSettingStore.addBlockedTagWithInfo(tag.name, translatedName: tag.translatedName)
                                showBlockTagToast = true
                                dismiss()
                            }) {
                                Label("屏蔽 tag", systemImage: "eye.slash")
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("简介")
                .font(.headline)
                .foregroundColor(.secondary)

            TranslatableText(text: TextCleaner.cleanDescription(illust.caption), font: .body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
        guard isLoggedIn else {
            showNotLoggedInToast = true
            return
        }

        Task {
            isFollowLoading = true
            defer { isFollowLoading = false }

            let userId = illust.user.id.stringValue

            do {
                if isFollowed {
                    try await PixivAPI.shared.unfollowUser(userId: userId)
                    isFollowed = false
                    illust.user.isFollowed = false
                } else {
                    try await PixivAPI.shared.followUser(userId: userId)
                    isFollowed = true
                    illust.user.isFollowed = true
                }
            } catch {
                print("Follow toggle failed: \(error)")
            }
        }
    }

    private func bookmarkIllust(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
        guard isLoggedIn else {
            showNotLoggedInToast = true
            return
        }

        let wasBookmarked = isBookmarked
        let illustId = illust.id

        if forceUnbookmark && wasBookmarked {
            isBookmarked = false
            illust.isBookmarked = false
            illust.totalBookmarks -= 1
            illust.bookmarkRestrict = nil
        } else if wasBookmarked {
            illust.bookmarkRestrict = isPrivate ? "private" : "public"
        } else {
            isBookmarked = true
            illust.isBookmarked = true
            illust.totalBookmarks += 1
            illust.bookmarkRestrict = isPrivate ? "private" : "public"
        }

        Task {
            do {
                if forceUnbookmark && wasBookmarked {
                    try await PixivAPI.shared.deleteBookmark(illustId: illustId)
                } else if wasBookmarked {
                    try await PixivAPI.shared.deleteBookmark(illustId: illustId)
                    try await PixivAPI.shared.addBookmark(illustId: illustId, isPrivate: isPrivate)
                } else {
                    try await PixivAPI.shared.addBookmark(illustId: illustId, isPrivate: isPrivate)
                }
            } catch {
                await MainActor.run {
                    if forceUnbookmark && wasBookmarked {
                        isBookmarked = true
                        illust.isBookmarked = true
                        illust.totalBookmarks += 1
                        illust.bookmarkRestrict = isPrivate ? "private" : "public"
                    } else if wasBookmarked {
                        illust.bookmarkRestrict = isPrivate ? "public" : "private"
                    } else {
                        isBookmarked = false
                        illust.isBookmarked = false
                        illust.totalBookmarks -= 1
                        illust.bookmarkRestrict = nil
                    }
                }
            }
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

import SwiftUI
import os.log

struct IllustDetailInfoSection: View {
    let illust: Illusts
    let userSettingStore: UserSettingStore
    let accountStore: AccountStore
    let colorScheme: ColorScheme

    @Binding var isFollowed: Bool
    @Binding var isBookmarked: Bool
    @Binding var totalComments: Int?
    @Binding var isBlockTriggered: Bool
    @Binding var isCommentsPanelPresented: Bool
    @Binding var navigateToUserId: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(ToastPresenter.self) private var toast
    @Environment(ThemeManager.self) var themeManager

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

        }
    }

    private var titleSection: some View {
        TranslatableText(text: illust.title, font: .title2)
            .fontWeight(.bold)
            .padding(.top, 2)
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
                NavigationLink(value: series) {
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
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .buttonStyle(GlassButtonStyle(color: isFollowed ? nil : themeManager.currentColor))
                .disabled(isFollowLoading)
                .sensoryFeedback(.impact(weight: .medium), trigger: isFollowed)
            }
        }
        .padding(.vertical, 4)
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
                urlString: illust.user.profileImageUrls?.px50x50
                    ?? illust.user.profileImageUrls?.medium,
                size: 48,
                expiration: DefaultCacheExpiration.userAvatar
            )

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
            #if os(iOS)
            Button(action: { isCommentsPanelPresented = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text(String(localized: "查看评论"))
                    if let totalComments = totalComments, totalComments > 0 {
                        Text("(\(totalComments))")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    Capsule()
                        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.18 : 0.08))
                }
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
                            .overlay(
                                Capsule()
                                    .strokeBorder(themeManager.currentColor.opacity(0.28), lineWidth: 1)
                            )
                    } else {
                        Capsule()
                            .fill(themeManager.currentColor)
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

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "标签"))
                .font(.headline)
                .foregroundColor(.secondary)

            FlowLayout(
                spacing: 6,
                reorderToFill: userSettingStore.userSetting.tagLayoutOptimizationEnabled
            ) {
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
                            Label(String(localized: "复制 tag"), systemImage: "doc.on.doc")
                        }

                        if isLoggedIn {
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

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "简介"))
                .font(.headline)
                .foregroundColor(.secondary)

            TranslatableText(text: illust.caption, font: .body)
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

    private func bookmarkIllust(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
        guard isLoggedIn else {
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
            guard accountStore.isCurrentAccount(
                generation: requestGeneration,
                userId: requestUserId
            ) else { return }
            isBookmarked = illust.isBookmarked
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

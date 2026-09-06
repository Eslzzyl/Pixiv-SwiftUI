import SwiftUI

struct ParentCommentHint: View {
    let parent: ParentComment
    @Environment(ThemeManager.self) var themeManager

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(String(localized: "回复"))
                .font(.caption2)
                .foregroundColor(.secondary)
            if let parentUser = parent.user?.name {
                Text("@\(parentUser)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.currentColor)
            }
        }
        .padding(.vertical, 2)
    }
}

struct CommentRowView: View {
    let comment: Comment
    let isReply: Bool
    var isExpanded: Bool = false
    var isLoadingReplies: Bool = false
    var workAuthorId: String?
    var onToggleExpand: (() -> Void)?
    let onUserTapped: (String) -> Void
    let currentUserId: String
    @Environment(ThemeManager.self) var themeManager

    var onReplyTapped: ((Comment) -> Void)?
    var onDeleteTapped: ((Comment) -> Void)?

    private var isOwnComment: Bool {
        guard let commentUserId = comment.user?.id else { return false }
        return String(commentUserId) == currentUserId
    }

    private var isWorkAuthor: Bool {
        guard let workAuthorId, let commentUserId = comment.user?.id else { return false }
        return String(commentUserId) == workAuthorId
    }

    private var avatarSize: CGFloat {
        isReply ? 30 : 38
    }

    var body: some View {
        HStack(alignment: .top, spacing: isReply ? 10 : 12) {
            if isReply {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 2)
                    .clipShape(Capsule())
                    .padding(.leading, 8)
                    .padding(.trailing, 2)
            }

            userAvatar

            VStack(alignment: .leading, spacing: 6) {
                userInfoRow

                if let parent = comment.parentComment {
                    ParentCommentHint(parent: parent)
                }

                commentContent

                metaActionRow
            }
        }
        .padding(.vertical, isReply ? 4 : 7)
    }

    private var userAvatar: some View {
        Group {
            if let user = comment.user,
               let avatarURL = user.profileImageUrls?.medium {
                Button(action: {
                    if let userId = user.id {
                        onUserTapped(String(userId))
                    }
                }) {
                    AnimatedAvatarImage(urlString: avatarURL, size: avatarSize)
                }
                .buttonStyle(.borderless)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: avatarSize, height: avatarSize)
            }
        }
    }

    private var userInfoRow: some View {
        HStack(alignment: .center, spacing: 6) {
            if let user = comment.user, let name = user.name {
                Button(action: {
                    if let userId = user.id {
                        onUserTapped(String(userId))
                    }
                }) {
                    Text(name)
                        .font(isReply ? .footnote : .subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .buttonStyle(.borderless)
            }

            if isWorkAuthor {
                authorBadge
            }

            Spacer(minLength: 8)

            if onDeleteTapped != nil, isOwnComment {
                deleteButton
            }
        }
    }

    private var authorBadge: some View {
        Text(String(localized: "作者"))
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(themeManager.currentColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(themeManager.currentColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var deleteButton: some View {
        Button(action: {
            onDeleteTapped?(comment)
        }) {
            Image(systemName: "trash")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
                .padding(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(String(localized: "删除评论"))
    }

    private var metaActionRow: some View {
        HStack(alignment: .center, spacing: 10) {
            if let date = comment.date {
                Text(formatDate(date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            replyButton

            Spacer(minLength: 8)

            if comment.hasReplies == true && !isReply && onToggleExpand != nil {
                expandRepliesButton
            }
        }
        .padding(.top, 2)
    }

    private var replyButton: some View {
        Button(action: {
            onReplyTapped?(comment)
        }) {
            HStack(spacing: 3) {
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.system(size: 10))
                Text(String(localized: "回复"))
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Color.secondary.opacity(0.08))
            .clipShape(Capsule())
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(String(localized: "回复此评论"))
    }

    private var commentContent: some View {
        Group {
            if let stamp = comment.stamp,
               let stampUrl = stamp.stampUrl {
                CachedAsyncImage(urlString: stampUrl)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let commentText = comment.comment {
                TranslatableCommentTextView(
                    text: TextCleaner.decodeHTMLEntities(commentText),
                    font: isReply ? .callout : .body
                )
            }
        }
    }

    @ViewBuilder
    private var expandRepliesButton: some View {
        if let onToggleExpand = onToggleExpand {
            Button(action: onToggleExpand) {
                HStack(spacing: 4) {
                    if isLoadingReplies {
                        ProgressView()
                            #if os(macOS)
                            .controlSize(.mini)
                            #else
                            .scaleEffect(0.6)
                            #endif
                            .frame(width: 10, height: 10)
                        Text(String(localized: "加载中..."))
                            .font(.system(size: 11))
                    } else {
                        Text(isExpanded ? String(localized: "收起回复") : String(localized: "展开回复"))
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                }
                .foregroundColor(themeManager.currentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(themeManager.currentColor.opacity(0.12))
                .clipShape(Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isExpanded ? String(localized: "收起回复") : String(localized: "展开回复"))
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var parsedDate = isoFormatter.date(from: dateString)
        if parsedDate == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            parsedDate = isoFormatter.date(from: dateString)
        }
        if parsedDate == nil {
            let fallback = DateFormatter()
            fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            parsedDate = fallback.date(from: dateString)
        }

        guard let date = parsedDate else {
            return dateString
        }

        let now = Date()
        let calendar = Calendar.current
        let displayFormatter = DateFormatter()
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            displayFormatter.dateFormat = "MM-dd HH:mm"
        } else {
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        }
        let absString = displayFormatter.string(from: date)

        let interval = now.timeIntervalSince(date)
        let relativeString: String?
        if interval >= 0 && interval < 60 {
            relativeString = String(localized: "刚刚")
        } else if interval >= 60 && interval < 86400 * 30 {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.unitsStyle = .full
            relativeString = relativeFormatter.localizedString(for: date, relativeTo: now)
        } else {
            relativeString = nil
        }

        if let relative = relativeString {
            return "\(absString) (\(relative))"
        } else {
            return absString
        }
    }
}

#Preview("CommentRowView") {
    let comment = Comment(
        id: 1,
        comment: "这是一条测试评论",
        date: "2024-01-15T12:00:00+09:00",
        user: CommentUser(
            id: 1,
            name: "测试用户",
            account: "test_user",
            profileImageUrls: CommentProfileImageUrls(medium: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg")
        ),
        parentComment: nil,
        hasReplies: true,
        stamp: nil
    )

    CommentRowView(
        comment: comment,
        isReply: false,
        workAuthorId: "1",
        onToggleExpand: {},
        onUserTapped: { _ in },
        currentUserId: "2"
    )
    .environment(ThemeManager())
    .padding()
}

#Preview("CommentRowView with parent") {
    let parent = ParentComment(
        id: 0,
        user: CommentUser(id: 2, name: "父评论用户", account: "parent_user", profileImageUrls: nil),
        comment: "父评论内容"
    )

    let comment = Comment(
        id: 2,
        comment: "这是一条回复评论",
        date: "2024-01-15T12:30:00+09:00",
        user: CommentUser(
            id: 3,
            name: "回复用户",
            account: "reply_user",
            profileImageUrls: CommentProfileImageUrls(medium: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p1.jpg")
        ),
        parentComment: parent,
        hasReplies: false,
        stamp: nil
    )

    CommentRowView(
        comment: comment,
        isReply: true,
        workAuthorId: "1",
        onUserTapped: { _ in },
        currentUserId: "2"
    )
    .environment(ThemeManager())
    .padding()
}

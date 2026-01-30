import SwiftUI

struct ParentCommentHint: View {
    let parent: ParentComment

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.caption2)
                .foregroundColor(.secondary)
            if let parentUser = parent.user?.name {
                Text("@\(parentUser)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            Text("的回复")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.leading, 8)
    }
}

struct CommentRowView: View {
    let comment: Comment
    let isReply: Bool
    var isExpanded: Bool = false
    var onToggleExpand: (() -> Void)?
    let onUserTapped: (String) -> Void

    var onReplyTapped: ((Comment) -> Void)?
    var onDeleteTapped: ((Comment) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isReply {
                Rectangle()
                    .frame(width: 24)
                    .foregroundColor(.clear)
            }

            userAvatar

            VStack(alignment: .leading, spacing: 4) {
                userInfoRow

                if let parent = comment.parentComment {
                    ParentCommentHint(parent: parent)
                }

                commentContent
            }
        }
        .padding(.vertical, 8)
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
                    CachedAsyncImage(urlString: avatarURL)
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
            }
        }
    }

    private var userInfoRow: some View {
        HStack(spacing: 8) {
            if let user = comment.user, let name = user.name {
                Button(action: {
                    if let userId = user.id {
                        onUserTapped(String(userId))
                    }
                }) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.plain)
            }

            if let date = comment.date {
                Text("· \(formatDate(date))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            replyButton

            if onDeleteTapped != nil {
                deleteButton
            }

            if comment.hasReplies == true && !isReply && onToggleExpand != nil {
                expandButton
            }
        }
    }

    private var deleteButton: some View {
        Button(action: {
            onDeleteTapped?(comment)
        }) {
            Image(systemName: "trash")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var replyButton: some View {
        Button(action: {
            onReplyTapped?(comment)
        }) {
            HStack(spacing: 4) {
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var expandButton: some View {
        if let onToggleExpand = onToggleExpand {
            Button(action: onToggleExpand) {
                HStack(spacing: 4) {
                    Text(isExpanded ? "收起" : "回复")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var commentContent: some View {
        Group {
            if let stamp = comment.stamp,
               let stampUrl = stamp.stampUrl {
                CachedAsyncImage(urlString: stampUrl)
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
            } else if let commentText = comment.comment {
                TranslatableCommentTextView(
                    text: TextCleaner.decodeHTMLEntities(commentText),
                    font: .subheadline
                )
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        if let parsedDate = formatter.date(from: dateString) {
            let displayFormatter = Foundation.DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            displayFormatter.timeZone = .current
            return displayFormatter.string(from: parsedDate)
        }

        return dateString
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
        onUserTapped: { _ in }
    )
    .padding()
}

#Preview("CommentRowView with parent") {
    let parent = ParentComment(
        id: 0,
        user: CommentUser(id: 2, name: "父评论用户", account: "parent_user", profileImageUrls: nil),
        comment: "父评论内容"
    )

    let comment = Comment(
        id: 1,
        comment: "这是一条回复评论",
        date: "2024-01-15T12:30:00+09:00",
        user: CommentUser(
            id: 1,
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
        isReply: false,
        onUserTapped: { _ in }
    )
    .padding()
}

#Preview("CommentRowView reply") {
    let comment = Comment(
        id: 1,
        comment: "这是一条回复评论",
        date: "2024-01-15T12:30:00+09:00",
        user: CommentUser(
            id: 1,
            name: "回复用户",
            account: "reply_user",
            profileImageUrls: CommentProfileImageUrls(medium: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p1.jpg")
        ),
        parentComment: nil,
        hasReplies: false,
        stamp: nil
    )

    CommentRowView(
        comment: comment,
        isReply: true,
        onUserTapped: { _ in }
    )
    .padding()
}

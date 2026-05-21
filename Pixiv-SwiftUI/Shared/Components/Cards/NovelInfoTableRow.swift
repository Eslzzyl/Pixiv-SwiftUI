import SwiftUI

enum NovelInfoDetailStyle {
    case author
    case metrics
}

struct NovelInfoTableRow: View {
    let novel: Novel
    var titlePrefix: String?
    var detailStyle: NovelInfoDetailStyle = .author
    var showsBookmarkSummary = false
    var isBookmarked: Bool? = nil
    var bookmarkSummaryText: String? = nil

    private var resolvedIsBookmarked: Bool {
        isBookmarked ?? novel.isBookmarked
    }

    private var resolvedBookmarkSummaryText: String {
        bookmarkSummaryText ?? NumberFormatter.formatCount(novel.totalBookmarks)
    }

    private var titleText: String {
        if let titlePrefix, !titlePrefix.isEmpty {
            return "\(titlePrefix)\(novel.title)"
        }
        return novel.title
    }

    private var tagSummary: String {
        let tags = novel.tags.prefix(4).map(\.name)
        if tags.isEmpty {
            return "—"
        }
        return tags.joined(separator: " / ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedAsyncImage(
                urlString: novel.imageUrls.medium,
                expiration: DefaultCacheExpiration.novel
            )
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    titleColumn
                        .gridCellColumns(2)

                    detailColumn
                        .frame(maxWidth: .infinity, alignment: .leading)

                    tagColumn
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsBookmarkSummary {
                bookmarkColumn
                    .frame(width: 44)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }

    private var titleColumn: some View {
        Text(titleText)
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(.primary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch detailStyle {
        case .author:
            Text(novel.user.name)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        case .metrics:
            VStack(alignment: .leading, spacing: 4) {
                Text(formatTextLength(novel.textLength))
                Text("\(NumberFormatter.formatCount(novel.totalBookmarks))收藏")
                Text("\(NumberFormatter.formatCount(novel.totalView))阅读")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
    }

    private var tagColumn: some View {
        Text(tagSummary)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
    }

    private var bookmarkColumn: some View {
        VStack(spacing: 4) {
            Image(systemName: resolvedIsBookmarked ? "heart.fill" : "heart")
                .foregroundColor(resolvedIsBookmarked ? .red : .secondary)
                .font(.system(size: 18))

            Text(resolvedBookmarkSummaryText)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
}

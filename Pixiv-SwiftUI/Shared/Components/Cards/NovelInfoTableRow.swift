import SwiftUI

enum NovelInfoDetailStyle {
    case author
    case metrics
}

struct NovelInfoTableRow: View {
    private enum Layout {
        static let thumbnailSize: CGFloat = 80
        static let tagRowHeight: CGFloat = 22
    }

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

    private var metricsSummary: String {
        "\(formatTextLength(novel.textLength)) / \(NumberFormatter.formatCount(novel.totalBookmarks))收藏 / \(NumberFormatter.formatCount(novel.totalView))阅读"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedAsyncImage(
                urlString: novel.imageUrls.medium,
                expiration: DefaultCacheExpiration.novel
            )
            .frame(width: Layout.thumbnailSize, height: Layout.thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                titleColumn
                detailColumn
                tagColumn
            }
            .frame(maxWidth: .infinity, minHeight: Layout.thumbnailSize, alignment: .topLeading)

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
            .lineLimit(2, reservesSpace: true)
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
                .lineLimit(1, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .metrics:
            Text(metricsSummary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var tagColumn: some View {
        if novel.tags.isEmpty {
            Text("—")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1, reservesSpace: true)
                .frame(maxWidth: .infinity, minHeight: Layout.tagRowHeight, alignment: .leading)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(novel.tags.prefix(4), id: \.name) { tag in
                        Text(tag.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: Layout.tagRowHeight, maxHeight: Layout.tagRowHeight, alignment: .leading)
        }
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

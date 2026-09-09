import SwiftUI

struct SpotlightCard: View {
    let article: SpotlightArticle
    var width: CGFloat = 200

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(
                urlString: article.thumbnail,
                aspectRatio: 1.9
            )
            .frame(width: width, height: width * 0.525)
            .clipped()

            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: width * 0.525)

            VStack(alignment: .leading, spacing: 2) {
                Text(article.displayTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(8)
        }
        .frame(width: width, height: width * 0.525)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            Button {
                openInBrowser(urlString: article.articleUrl)
            } label: {
                Label(String(localized: "在浏览器中打开"), systemImage: "safari")
            }
        }
    }
}

struct SpotlightListCard: View {
    let article: SpotlightArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(
                urlString: article.thumbnail,
                aspectRatio: 1.9
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(article.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2, reservesSpace: true)

                Text(formattedDate(article.publishDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contextMenu {
            Button {
                openInBrowser(urlString: article.articleUrl)
            } label: {
                Label(String(localized: "在浏览器中打开"), systemImage: "safari")
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private func openInBrowser(urlString: String) {
    guard let url = URL(string: urlString) else { return }
    #if os(iOS)
    UIApplication.shared.open(url)
    #elseif os(macOS)
    NSWorkspace.shared.open(url)
    #endif
}

struct SkeletonSpotlightCard: View {
    var width: CGFloat = 200

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: width, height: width * 0.525)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .skeleton()
    }
}

struct SkeletonSpotlightRelatedCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 140, height: 140)
                .skeleton()

            VStack(alignment: .leading, spacing: 2) {
                SkeletonView(height: 12, width: 44, cornerRadius: 2)
                SkeletonView(height: 14, width: 124, cornerRadius: 2)
                SkeletonView(height: 14, width: 96, cornerRadius: 2)
            }
            .frame(width: 140, alignment: .leading)
        }
    }
}

#Preview {
    HStack {
        SpotlightCard(
            article: SpotlightArticle(
                id: 1,
                title: "#猫猫日特辑 那些可爱的猫猫",
                pureTitle: "那些可爱的猫猫",
                thumbnail: "https://example.com/image.jpg",
                articleUrl: "https://example.com/article",
                publishDate: Date()
            )
        )
        SpotlightCard(
            article: SpotlightArticle(
                id: 2,
                title: "#春天特辑 美丽的风景",
                pureTitle: "美丽的风景",
                thumbnail: "https://example.com/image2.jpg",
                articleUrl: "https://example.com/article2",
                publishDate: Date()
            )
        )
    }
    .padding()
}

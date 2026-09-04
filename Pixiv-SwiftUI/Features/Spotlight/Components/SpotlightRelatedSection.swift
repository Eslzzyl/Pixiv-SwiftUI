import SwiftUI

struct SpotlightRelatedSection: View {
    let title: String
    let articles: [SpotlightRelatedArticle]
    let onArticleTap: (SpotlightRelatedArticle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 4, height: 18)
                Text(title)
                    .font(.headline)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(articles) { article in
                        SpotlightRelatedCard(article: article) {
                            onArticleTap(article)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct SpotlightRelatedCard: View {
    let article: SpotlightRelatedArticle
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                CachedAsyncImage(
                    urlString: article.thumbnail,
                    aspectRatio: 1
                )
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    if !article.category.isEmpty {
                        Text(article.category)
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }

                    Text(article.title)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                openInBrowser(urlString: article.articleUrl)
            } label: {
                Label(String(localized: "在浏览器中打开"), systemImage: "safari")
            }
        }
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

#Preview {
    VStack(spacing: 24) {
        SpotlightRelatedSection(
            title: "本月排行榜",
            articles: [
                SpotlightRelatedArticle(
                    id: 1,
                    title: "低调展现魅力♡ - 内层挑染插画特辑 -",
                    thumbnail: "https://i.pximg.net/c/260x260_80/img-master/img/2025/06/19/17/30/01/131734918_p0_square1200.jpg",
                    articleUrl: "https://www.pixivision.net/zh/a/11175",
                    category: "插画"
                ),
                SpotlightRelatedArticle(
                    id: 2,
                    title: "跨越万里只为你！",
                    thumbnail: "https://i.pximg.net/c/260x260_80/img-master/img/2026/01/31/22/33/11/140607518_p0_square1200.jpg",
                    articleUrl: "https://www.pixivision.net/zh/a/11469",
                    category: "插画"
                )
            ],
            onArticleTap: { _ in }
        )

        SpotlightRelatedSection(
            title: "推荐",
            articles: [
                SpotlightRelatedArticle(
                    id: 3,
                    title: "覆盖的美感 - 长手套插画特辑 -",
                    thumbnail: "https://i.pximg.net/c/260x260_80/img-master/img/2025/06/19/01/02/47/131717936_p0_square1200.jpg",
                    articleUrl: "https://www.pixivision.net/zh/a/10818",
                    category: "插画"
                )
            ],
            onArticleTap: { _ in }
        )
    }
    .padding()
}

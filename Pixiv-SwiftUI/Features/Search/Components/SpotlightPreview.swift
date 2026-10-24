import SwiftUI

struct SpotlightPreview: View {
    @State private var store = SpotlightStore()

    var body: some View {
        GeometryReader { proxy in
            content(cardWidth: min(max(proxy.size.width * 0.65, 220), 320))
        }
        .frame(height: 180)
        .task {
            if store.articles.isEmpty {
                await store.fetch()
            }
        }
    }

    private func content(cardWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                NavigationLink(value: PixivNavigationRoute.spotlightList) {
                    HStack(spacing: 4) {
                        Text(String(localized: "亮点"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal)

            if store.isLoading && store.articles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonSpotlightCard(width: cardWidth)
                        }
                    }
                    .padding(.horizontal)
                }
            } else if store.articles.isEmpty {
                HStack {
                    Spacer()
                    Text(String(localized: "暂无亮点内容"))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 100)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.articles.prefix(10)) { article in
                            NavigationLink(value: PixivNavigationRoute.spotlightArticle(article)) {
                                SpotlightCard(article: article, width: cardWidth)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top, 16)
    }
}

#Preview {
    NavigationStack {
        SpotlightPreview()
    }
}

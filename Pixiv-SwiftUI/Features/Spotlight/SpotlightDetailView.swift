import SwiftUI

struct SpotlightDetailView: View {
    let article: SpotlightArticle

    @State private var store = SpotlightDetailStore()

    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(AccountStore.self) var accountStore
    @Environment(\.pixivNavigationRouter) private var navigationRouter

    #if os(macOS)
    @State private var columnCount: Int = 4
    #elseif os(iOS)
    @State private var columnCount: Int = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
    #endif
    @State private var waterfallWidth: CGFloat = 0

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerView

                if store.isLoading && store.detail == nil {
                    skeletonView
                        .transition(.opacity)
                } else if let detail = store.detail {
                    contentView(detail)
                        .transition(.opacity)
                } else if let error = store.error {
                    errorView(error)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.25), value: store.isLoading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #if os(macOS)
        .navigationTitle(article.displayTitle)
        #else
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let articleUrl = URL(string: article.articleUrl) {
                    ShareLink(item: articleUrl) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            if store.detail == nil {
                await store.fetch(url: article.articleUrl)
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            CachedAsyncImage(
                urlString: article.thumbnail,
                aspectRatio: 1.9
            )
            .frame(maxWidth: .infinity)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text(article.displayTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                if article.publishDate != .distantPast {
                    HStack {
                        Image(systemName: "calendar")
                        Text(formattedDate(article.publishDate))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private var skeletonView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Description skeleton
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.3))
                        .frame(width: 4, height: 18)
                    SkeletonView(height: 18, width: 60)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SkeletonView(height: 12)
                    SkeletonView(height: 12, width: 200)
                    SkeletonView(height: 12, width: 150)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top, 20)

            // Works section skeleton
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.3))
                        .frame(width: 4, height: 18)
                    SkeletonView(height: 18, width: 80)
                    Spacer()
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount), spacing: 8) {
                    ForEach(0..<min(columnCount * 2, 6), id: \.self) { _ in
                        SkeletonRoundedRectangle(height: 120)
                    }
                }
            }
            .padding(.horizontal, 8)

            // Related sections skeleton
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.3))
                        .frame(width: 4, height: 18)
                    SkeletonView(height: 18, width: 100)
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonSpotlightCard(width: 140)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func contentView(_ detail: SpotlightArticleDetail) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            if !detail.description.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 4, height: 18)
                        Text(String(localized: "简介"))
                            .font(.headline)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        let paragraphs = descriptionParagraphs(detail.description)
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                            descriptionText(paragraph)
                                .font(.body)
                                .foregroundColor(.primary.opacity(0.8))
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                    .textSelection(.enabled)
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }

            if !detail.works.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 4, height: 18)
                        Text(String(localized: "收录作品"))
                            .font(.headline)

                        Spacer()

                        Text("\(detail.works.count) 项")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    WaterfallGrid(
                        data: detail.works,
                        columnCount: columnCount,
                        spacing: 8,
                        width: waterfallWidth > 0 ? waterfallWidth : nil
                    ) { work, columnWidth in
                        SpotlightWorkCard(work: work, columnWidth: columnWidth) {
                            navigationRouter?.push(.illustLoader(id: work.id))
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .background(GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            waterfallWidth = max(geometry.size.width - 16, 0)
                        }
                        .onChange(of: geometry.size.width) { _, newWidth in
                            waterfallWidth = max(newWidth - 16, 0)
                        }
                })
            }

            if !detail.referencedArticleSections.isEmpty {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 4, height: 18)
                        Text(String(localized: "收录特辑"))
                            .font(.headline)

                        Spacer()

                        let totalCount = detail.referencedArticleSections.reduce(0) { $0 + $1.articles.count }
                        Text("\(totalCount) 项")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    ForEach(detail.referencedArticleSections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.heading)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(section.articles) { article in
                                    Button {
                                        navigationRouter?.push(.spotlightArticle(article))
                                    } label: {
                                        SpotlightListCard(article: article)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }

            if !detail.rankingArticles.isEmpty {
                SpotlightRelatedSection(
                    title: String(localized: "本月排行榜"),
                    articles: detail.rankingArticles,
                    onArticleTap: { article in
                        navigationRouter?.push(.spotlightRelatedArticle(article))
                    }
                )
            }

            if !detail.recommendedArticles.isEmpty {
                SpotlightRelatedSection(
                    title: String(localized: "推荐"),
                    articles: detail.recommendedArticles,
                    onArticleTap: { article in
                        navigationRouter?.push(.spotlightRelatedArticle(article))
                    }
                )
            }

            if detail.works.isEmpty && detail.description.isEmpty {
                Text(String(localized: "暂无内容"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
            }
        }
        .padding(.bottom, 32)
    }

    private func errorView(_ error: AppError) -> some View {
        ErrorStateView(message: error.localizedDescription ?? "未知错误", retryAction: {
            Task {
                await store.fetch(url: article.articleUrl)
            }
        })
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    private func descriptionParagraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func descriptionText(_ text: String) -> Text {
        parseStyledSegments(text).reduce(Text("")) { partial, segment in
            var current = Text(segment.text)
            if segment.isBold {
                current = current.bold()
            }
            if segment.isItalic {
                current = current.italic()
            }
            return partial + current
        }
    }

    private func parseStyledSegments(_ text: String) -> [(text: String, isBold: Bool, isItalic: Bool)] {
        var segments: [(text: String, isBold: Bool, isItalic: Bool)] = []
        var buffer = ""
        var isBold = false
        var isItalic = false
        var index = text.startIndex

        func appendBufferIfNeeded() {
            guard !buffer.isEmpty else { return }
            segments.append((buffer, isBold, isItalic))
            buffer = ""
        }

        while index < text.endIndex {
            let remaining = text[index...]

            if remaining.hasPrefix("[[B]]") {
                appendBufferIfNeeded()
                isBold = true
                index = text.index(index, offsetBy: 5)
                continue
            }

            if remaining.hasPrefix("[[/B]]") {
                appendBufferIfNeeded()
                isBold = false
                index = text.index(index, offsetBy: 6)
                continue
            }

            if remaining.hasPrefix("[[I]]") {
                appendBufferIfNeeded()
                isItalic = true
                index = text.index(index, offsetBy: 5)
                continue
            }

            if remaining.hasPrefix("[[/I]]") {
                appendBufferIfNeeded()
                isItalic = false
                index = text.index(index, offsetBy: 6)
                continue
            }

            buffer.append(text[index])
            index = text.index(after: index)
        }

        appendBufferIfNeeded()

        return segments
    }

}

#Preview {
    NavigationStack {
        SpotlightDetailView(
            article: SpotlightArticle(
                id: 1,
                title: "#猫猫日特辑 那些可爱的猫猫",
                pureTitle: "那些可爱的猫猫",
                thumbnail: "https://example.com/image.jpg",
                articleUrl: "https://example.com/article",
                publishDate: Date()
            )
        )
    }
}

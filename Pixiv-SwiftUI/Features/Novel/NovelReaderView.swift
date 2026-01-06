import SwiftUI
import Kingfisher

struct NovelReaderView: View {
    let novelId: Int
    @State private var store: NovelReaderStore
    @Environment(UserSettingStore.self) private var userSettingStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSettings = false
    @State private var navigateToIllust: Int?
    @State private var navigateToNovel: Int?
    @State private var showSeriesNavigation = false
    @State private var selectedTab = 0

    init(novelId: Int) {
        self.novelId = novelId
        _store = State(initialValue: NovelReaderStore(novelId: novelId))
    }

    var body: some View {
        ZStack {
            readerBackground
            contentView
        }
        .navigationTitle(store.novel?.title ?? "加载中...")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showSettings = true }) {
                        Label("阅读设置", systemImage: "textformat.size")
                    }

                    Button(action: {
                        if store.isPositionBooked {
                            store.clearPosition()
                        } else {
                            store.savePosition()
                        }
                    }) {
                        Label(
                            store.isPositionBooked ? "取消书签" : "添加书签",
                            systemImage: store.isPositionBooked ? "bookmark.slash" : "bookmark"
                        )
                    }

                    if store.seriesNavigation?.prevNovel != nil || store.seriesNavigation?.nextNovel != nil {
                        Divider()

                        Button(action: { showSeriesNavigation = true }) {
                            Label("系列导航", systemImage: "list.bullet")
                        }
                    }

                    Button(action: {
                        Task {
                            await store.translateAllParagraphs()
                        }
                    }) {
                        Label("全文翻译", systemImage: "globe")
                    }

                    Divider()

                    ShareLink(item: "https://www.pixiv.net/novel/show.php?id=\(novelId)") {
                        Label("分享链接", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NovelReaderSettingsView(store: store)
        }
        .sheet(isPresented: $showSeriesNavigation) {
            SeriesNavigationView(store: store)
        }
        .navigationDestination(item: $navigateToNovel) { novelId in
            NovelReaderView(novelId: novelId)
        }
        .navigationDestination(item: $navigateToIllust) { illustId in
            IllustDetailView(illust: Illusts(
                id: illustId,
                title: "",
                type: "illust",
                imageUrls: ImageUrls(squareMedium: "", medium: "", large: ""),
                caption: "",
                restrict: 0,
                user: User(profileImageUrls: nil, id: StringIntValue.string("0"), name: "", account: ""),
                tags: [],
                tools: [],
                createDate: "",
                pageCount: 1,
                width: 0,
                height: 0,
                sanityLevel: 0,
                xRestrict: 0,
                metaSinglePage: nil,
                metaPages: [],
                totalView: 0,
                totalBookmarks: 0,
                isBookmarked: false,
                bookmarkRestrict: nil,
                visible: true,
                isMuted: false,
                illustAIType: 0
            ))
        }
        .onAppear {
            print("[NovelReaderView] onAppear, novelId: \(novelId)")
            Task {
                await store.fetch()
            }
        }
    }

    @ViewBuilder
    private var readerBackground: some View {
        Color(store.settings.theme.backgroundColor)
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var contentView: some View {
        if store.isLoading {
            ProgressView("加载中...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = store.errorMessage {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("加载失败")
                    .font(.headline)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("重试") {
                    Task {
                        await store.fetch()
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    headerSection

                    contentSection

                    Divider()
                        .padding(.vertical, 20)

                    seriesNavigationSection

                    Spacer(minLength: 100)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            if let novel = store.novel {
                coverSection(novel)
                titleSection(novel)
                authorSection(novel)
                metadataSection(novel)
                tagsSection(novel)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func coverSection(_ novel: NovelReaderContent) -> some View {
        HStack {
            Spacer()
            CachedAsyncImage(
                urlString: novel.coverUrl,
                expiration: DefaultCacheExpiration.novel
            )
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Spacer()
        }
    }

    private func titleSection(_ novel: NovelReaderContent) -> some View {
        VStack(spacing: 4) {
            Text(novel.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            if let seriesTitle = novel.seriesTitle {
                HStack(spacing: 4) {
                    Image(systemName: "books.vertical")
                        .font(.caption)
                    Text("系列: \(seriesTitle)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
    }

    private func authorSection(_ novel: NovelReaderContent) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("用户ID: \(novel.userId)")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Text(formatDate(novel.createDate))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func metadataSection(_ novel: NovelReaderContent) -> some View {
        HStack(spacing: 16) {
            Label("\(novel.totalView)", systemImage: "eye")
            Label("\(novel.totalBookmarks)", systemImage: "heart")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func tagsSection(_ novel: NovelReaderContent) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(novel.tags, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(store.spans.enumerated()), id: \.offset) { index, span in
                NovelSpanRenderer(
                    span: span,
                    store: store,
                    paragraphIndex: index,
                    onImageTap: { illustId in
                        navigateToIllust = illustId
                    },
                    onLinkTap: { url in
                        openExternalLink(url)
                    }
                )
            }
        }
        .padding(.top, 20)
    }

    private var seriesNavigationSection: some View {
        VStack(spacing: 12) {
            if let prev = store.seriesNavigation?.prevNovel {
                Button(action: {
                    navigateToNovel = prev.id
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        VStack(alignment: .leading) {
                            Text("上一章")
                                .font(.caption)
                            Text(prev.title)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            if let next = store.seriesNavigation?.nextNovel {
                Button(action: {
                    navigateToNovel = next.id
                }) {
                    HStack {
                        Spacer()
                        Text(next.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        VStack(alignment: .trailing) {
                            Text("下一章")
                                .font(.caption)
                            Image(systemName: "chevron.right")
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd"
        return displayFormatter.string(from: date)
    }

    private func openExternalLink(_ url: String) {
        guard let url = URL(string: url) else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}

struct SeriesNavigationView: View {
    @Bindable var store: NovelReaderStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let prev = store.seriesNavigation?.prevNovel {
                    Section("上一章") {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text(prev.title)
                                Spacer()
                            }
                        }
                    }
                }

                if let next = store.seriesNavigation?.nextNovel {
                    Section("下一章") {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Text(next.title)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                }
            }
            .navigationTitle("系列导航")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NovelReaderView(novelId: 12345)
}

import SwiftUI
import TranslationKit

struct NovelSeriesView: View {
    let seriesId: Int
    @State private var store: NovelSeriesStore
    
    init(seriesId: Int) {
        self.seriesId = seriesId
        self._store = State(initialValue: NovelSeriesStore(seriesId: seriesId))
    }
    
    var body: some View {
        ScrollView {
            Group {
                if store.isLoading && store.seriesDetail == nil {
                    loadingView
                } else if let error = store.errorMessage {
                    errorView(error)
                } else if let detail = store.seriesDetail {
                    content(detail)
                }
            }
        }
        .id("SeriesScrollView-\(seriesId)")  // 添加稳定的 ID
        .navigationDestination(for: Novel.self) { novel in
            NovelDetailView(novel: novel)
        }
        .onAppear {
            print("[NovelSeriesView] onAppear - seriesId: \(seriesId)")
        }
        .refreshable {
            await store.fetch()
        }
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let detail = store.seriesDetail {
                    HStack(spacing: 8) {
                        CachedAsyncImage(
                            urlString: detail.user.profileImageUrls.medium,
                            expiration: DefaultCacheExpiration.userAvatar
                        )
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                        
                        Text(detail.user.name)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: shareSeries) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task {
            if store.seriesDetail == nil {
                await store.fetch()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("加载中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("加载失败")
                .font(.headline)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重试") {
                Task {
                    await store.fetch()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func content(_ detail: NovelSeriesDetail) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            seriesHeader(detail)
            
            Divider()
            
            if !store.novels.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("小说列表")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    novelList
                }
            }
        }
        .padding()
    }
    
    private func seriesHeader(_ detail: NovelSeriesDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TranslatableText(text: detail.title, font: .title2)
                .fontWeight(.bold)
            
            if let caption = detail.caption, !caption.isEmpty {
                TranslatableText(
                    text: TextCleaner.cleanDescription(caption),
                    font: .body
                )
                .foregroundColor(.secondary)
                .lineSpacing(4)
            }
            
            HStack(spacing: 16) {
                if detail.isConcluded {
                    Label("已完结", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("连载中", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Label("\(detail.contentCount)章", systemImage: "doc.text.fill")
                    .font(.caption)
                
                Label("\(formatCharacterCount(detail.totalCharacterCount))", systemImage: "character.book.closed")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            if let latestNovel = store.novels.first {
                NavigationLink(value: latestNovel) {
                    Label("查看最新章节", systemImage: "arrow.right.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var novelList: some View {
        VStack(spacing: 12) {
            ForEach(Array(store.novels.enumerated()), id: \.element.id) { index, novel in
                NavigationLink(value: novel) {
                    NovelSeriesCard(novel: novel, index: index)
                }
                
                if index < store.novels.count - 1 {
                    Divider()
                }
                
                if index == store.novels.count - 1 && store.nextUrl != nil && !store.isLoadingMore {
                    Color.clear
                        .frame(height:1)
                        .onAppear {
                            Task {
                                await store.loadMore()
                            }
                        }
                }
            }
            
            if store.isLoadingMore {
                HStack {
                    ProgressView()
                    Text("加载中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }
    
    private func formatCharacterCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1f万字", Double(count) / 10000)
        } else if count >= 1000 {
            return String(format: "%.1f千字", Double(count) / 1000)
        }
        return "\(count)字"
    }
    
    private func shareSeries() {
        guard let detail = store.seriesDetail else { return }
        guard let url = URL(string: "https://www.pixiv.net/novel/series/\(detail.id)") else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}

#Preview {
    NavigationStack {
        NovelSeriesView(seriesId: 1)
    }
}

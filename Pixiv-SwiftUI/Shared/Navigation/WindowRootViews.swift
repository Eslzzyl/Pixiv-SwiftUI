import SwiftUI
import Observation

struct IllustWindowRootView: View {
    let illustID: Int
    @State private var illust: Illusts?
    @State private var isLoading = true
    @State private var error: Error?

    @Environment(IllustStore.self) var illustStore

    var body: some View {
        NavigationStack {
            Group {
                if let illust = illust {
                    IllustDetailView(illust: illust)
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = error {
                    ContentUnavailableView(
                        "加载失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.localizedDescription)
                    )
                }
            }
            .pixivNavigationDestinations()
            #if os(macOS)
            .frame(minWidth: 800, minHeight: 600)
            #endif
        }
        .task {
            await loadIllust()
        }
    }

    private func loadIllust() async {
        do {
            // Try to get from local store first
            if let local = try? illustStore.getIllust(illustID) {
                self.illust = local
                self.isLoading = false
                return
            }

            // Otherwise fetch from API
            let detail = try await PixivAPI.shared.getIllustDetail(illustId: illustID)
            self.illust = detail
            self.isLoading = false
            // Save to store for future use
            try? illustStore.recordGlance(illustID, illust: detail)
        } catch {
            self.error = error
            self.isLoading = false
        }
    }
}

struct NovelWindowRootView: View {
    let novelID: Int
    @State private var novel: Novel?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            Group {
                if let novel = novel {
                    NovelDetailView(novel: novel)
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = error {
                    ContentUnavailableView(
                        "加载失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.localizedDescription)
                    )
                }
            }
            .pixivNavigationDestinations()
            #if os(macOS)
            .frame(minWidth: 800, minHeight: 600)
            #endif
        }
        .task {
            await loadNovel()
        }
    }

    private func loadNovel() async {
        do {
            // Try to get from local store first
            if let local = try? NovelStore.shared.getNovel(novelID) {
                self.novel = local
                self.isLoading = false
                return
            }

            let detail = try await PixivAPI.shared.getNovelDetail(novelId: novelID)
            self.novel = detail
            self.isLoading = false
            // Save to store for future use
            try? NovelStore.shared.recordGlance(novelID, novel: detail)
        } catch {
            self.error = error
            self.isLoading = false
        }
    }
}

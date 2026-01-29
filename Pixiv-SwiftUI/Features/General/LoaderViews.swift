import SwiftUI

struct IllustIdTarget: Hashable {
    let id: Int
}

struct NovelIdTarget: Hashable {
    let id: Int
}

struct IllustLoaderView: View {
    let illustId: Int
    @State private var illust: Illusts?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let illust = illust {
                IllustDetailView(illust: illust)
            } else if isLoading {
                ProgressView()
                    .onAppear {
                        loadIllust()
                    }
            } else {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "加载失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage ?? "未知错误")
                    )
                    Button("重试") {
                        loadIllust()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func loadIllust() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let illust = try await PixivAPI.shared.getIllustDetail(illustId: illustId)
                await MainActor.run {
                    self.illust = illust
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct NovelLoaderView: View {
    let novelId: Int
    @State private var novel: Novel?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let novel = novel {
                NovelDetailView(novel: novel)
            } else if isLoading {
                ProgressView()
                    .onAppear {
                        loadNovel()
                    }
            } else {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "加载失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage ?? "未知错误")
                    )
                    Button("重试") {
                        loadNovel()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func loadNovel() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let novel = try await PixivAPI.shared.getNovelDetail(novelId: novelId)
                await MainActor.run {
                    self.novel = novel
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

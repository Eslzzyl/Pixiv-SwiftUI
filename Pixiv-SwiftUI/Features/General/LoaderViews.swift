import SwiftUI

struct IllustLoaderView: View {
    let illustId: Int
    @State private var illust: Illusts?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let illust = illust {
                IllustDetailBrowserView(illust: illust)
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            } else if isLoading {
                illustDetailSkeleton
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
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

    private var illustDetailSkeleton: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 主图骨架
                SkeletonRoundedRectangle(height: 400)

                // 标题和作者
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonView(height: 22, width: 280, cornerRadius: 4)
                    SkeletonView(height: 16, width: 160, cornerRadius: 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // 操作按钮行
                HStack(spacing: 16) {
                    SkeletonCapsule(width: 60, height: 32)
                    SkeletonCapsule(width: 60, height: 32)
                    SkeletonCapsule(width: 60, height: 32)
                    Spacer()
                }
                .padding(.horizontal)

                // 描述段落
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonView(height: 14, width: nil, cornerRadius: 2)
                    SkeletonView(height: 14, width: nil, cornerRadius: 2)
                    SkeletonView(height: 14, width: 180, cornerRadius: 2)
                }
                .padding(.horizontal)

                // 信息行
                HStack(spacing: 24) {
                    SkeletonView(height: 12, width: 60, cornerRadius: 2)
                    SkeletonView(height: 12, width: 80, cornerRadius: 2)
                    SkeletonView(height: 12, width: 70, cornerRadius: 2)
                    Spacer()
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private func loadIllust() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let illust = try await PixivAPI.shared.illustAPI.getIllustDetail(illustId: illustId)
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
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            } else if isLoading {
                novelDetailSkeleton
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
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

    private var novelDetailSkeleton: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 封面图骨架
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .skeleton()
                    .padding(.horizontal)

                // 标题和作者
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonView(height: 22, width: 300, cornerRadius: 4)
                    SkeletonView(height: 16, width: 140, cornerRadius: 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // 操作按钮行
                HStack(spacing: 16) {
                    SkeletonCapsule(width: 70, height: 32)
                    SkeletonCapsule(width: 70, height: 32)
                    Spacer()
                }
                .padding(.horizontal)

                // 简介段落
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonView(height: 14, width: nil, cornerRadius: 2)
                    SkeletonView(height: 14, width: nil, cornerRadius: 2)
                    SkeletonView(height: 14, width: nil, cornerRadius: 2)
                    SkeletonView(height: 14, width: 200, cornerRadius: 2)
                }
                .padding(.horizontal)

                // 标签行
                HStack(spacing: 8) {
                    SkeletonCapsule(width: 50, height: 24)
                    SkeletonCapsule(width: 70, height: 24)
                    SkeletonCapsule(width: 40, height: 24)
                    Spacer()
                }
                .padding(.horizontal)

                // 信息行
                HStack(spacing: 24) {
                    SkeletonView(height: 12, width: 50, cornerRadius: 2)
                    SkeletonView(height: 12, width: 70, cornerRadius: 2)
                    Spacer()
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private func loadNovel() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let novel = try await PixivAPI.shared.novelAPI.getNovelDetail(novelId: novelId)
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

struct SpotlightArticleTarget: Hashable {
    let id: Int
    let title: String
    let thumbnail: String
    let articleUrl: String
}

import SwiftUI

struct IllustDetailRelatedSection: View {
    let illustId: Int
    let isLoggedIn: Bool

    @Binding var relatedIllusts: [Illusts]
    @Binding var isLoadingRelated: Bool
    @Binding var isFetchingMoreRelated: Bool
    @Binding var relatedNextUrl: String?
    @Binding var hasMoreRelated: Bool
    @Binding var relatedIllustError: String?

    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.horizontal)
                .padding(.bottom, 8)

            Text("相关推荐")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if !isLoggedIn {
                notLoggedInView
            } else if isLoadingRelated {
                loadingView
            } else if relatedIllustError != nil {
                errorView
            } else if relatedIllusts.isEmpty {
                emptyView
            } else {
                illustsGridView
            }
        }
        .frame(maxWidth: width)
        .padding(.bottom, 30)
        .onAppear {
            if isLoggedIn && relatedIllusts.isEmpty && !isLoadingRelated {
                fetchRelatedIllusts()
            }
        }
    }

    private var notLoggedInView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                Text("请登录后查看相关推荐")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(height: 150)
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(height: 200)
    }

    private var errorView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.secondary)
                Text("加载失败")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Button("重试") {
                    fetchRelatedIllusts()
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(height: 200)
    }

    private var emptyView: some View {
        HStack {
            Spacer()
            Text("暂无相关推荐")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(height: 200)
    }

    private var illustsGridView: some View {
        VStack(spacing: 12) {
            WaterfallGrid(
                data: relatedIllusts,
                columnCount: width > 1200 ? 5 : (width > 800 ? 4 : 3),
                width: width - 24
            ) { relatedIllust, columnWidth in
                NavigationLink(value: relatedIllust) {
                    RelatedIllustCard(illust: relatedIllust, showTitle: false, columnWidth: columnWidth)
                }
                .buttonStyle(.plain)
            }

            if hasMoreRelated {
                LazyVStack {
                    HStack {
                        Spacer()
                        ProgressView()
                            .id(relatedNextUrl)
                            .onAppear {
                                loadMoreRelatedIllusts()
                            }
                        Spacer()
                    }
                    .padding(.vertical)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private func fetchRelatedIllusts() {
        isLoadingRelated = true
        relatedIllustError = nil
        relatedNextUrl = nil
        hasMoreRelated = true

        Task {
            do {
                let result = try await PixivAPI.shared.getRelatedIllusts(illustId: illustId)
                await MainActor.run {
                    self.relatedIllusts = result.illusts
                    self.relatedNextUrl = result.nextUrl
                    self.hasMoreRelated = result.nextUrl != nil
                    self.isLoadingRelated = false
                }
            } catch {
                await MainActor.run {
                    self.relatedIllustError = error.localizedDescription
                    self.isLoadingRelated = false
                }
            }
        }
    }

    private func loadMoreRelatedIllusts() {
        guard let nextUrl = relatedNextUrl, !isFetchingMoreRelated && hasMoreRelated else { return }

        isFetchingMoreRelated = true

        Task {
            do {
                let result = try await PixivAPI.shared.getIllustsByURL(nextUrl)
                await MainActor.run {
                    self.relatedIllusts.append(contentsOf: result.illusts)
                    self.relatedNextUrl = result.nextUrl
                    self.hasMoreRelated = result.nextUrl != nil
                    self.isFetchingMoreRelated = false
                }
            } catch {
                await MainActor.run {
                    self.isFetchingMoreRelated = false
                }
            }
        }
    }
}

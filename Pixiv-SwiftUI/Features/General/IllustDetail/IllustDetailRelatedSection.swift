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

    @Environment(UserSettingStore.self) var settingStore

    let width: CGFloat

    #if os(macOS)
    @State private var dynamicColumnCount: Int = 4
    #else
    @State private var dynamicColumnCount: Int = 2
    #endif

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
        VStack(alignment: .leading, spacing: 12) {
            WaterfallGrid(
                data: relatedIllusts,
                columnCount: dynamicColumnCount,
                width: width - 24
            ) { relatedIllust, columnWidth in
                NavigationLink(value: relatedIllust) {
                    RelatedIllustCard(illust: relatedIllust, showTitle: false, columnWidth: columnWidth)
                }
                .buttonStyle(.plain)
            }

            if hasMoreRelated {
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
        .padding(.horizontal, 12)
        .responsiveGridColumnCount(userSetting: settingStore.userSetting, columnCount: $dynamicColumnCount)
        .frame(minHeight: 300)
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
                    // 过滤掉当前插画
                    self.relatedIllusts = result.illusts.filter { $0.id != illustId }
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
                    // 过滤掉已存在的和当前的插画
                    let newIllusts = result.illusts.filter { new in
                        !self.relatedIllusts.contains(where: { $0.id == new.id }) && new.id != illustId
                    }
                    if newIllusts.isEmpty && result.nextUrl != nil {
                        // 如果这一页全是重复的，但还有下一页，尝试递归加载下一页
                        self.relatedNextUrl = result.nextUrl
                        self.isFetchingMoreRelated = false
                        loadMoreRelatedIllusts()
                    } else {
                        self.relatedIllusts.append(contentsOf: newIllusts)
                        self.relatedNextUrl = result.nextUrl
                        self.hasMoreRelated = result.nextUrl != nil
                        self.isFetchingMoreRelated = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isFetchingMoreRelated = false
                }
            }
        }
    }
}

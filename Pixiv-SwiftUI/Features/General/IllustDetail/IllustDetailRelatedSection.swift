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

    private var filteredIllusts: [Illusts] {
        settingStore.filterIllusts(relatedIllusts)
    }

    private var actualColumnCount: Int {
        #if os(macOS)
        // 在详情页侧边栏中，调整列数触发阈值以适应较窄的宽度
        if width < 450 {
            return 3
        } else if width < 750 {
            return 4
        } else {
            return 5
        }
        #else
        return dynamicColumnCount
        #endif
    }

    @State private var dynamicColumnCount: Int = 2
    @State private var loadMoreError: String?

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
                // 如果原始列表为空，显示暂无数据
                emptyView
            } else if filteredIllusts.isEmpty && !relatedIllusts.isEmpty {
                // 如果被过滤光了，显示过滤提示
                VStack(spacing: 8) {
                    Text("由于设置，部分内容已被过滤")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if hasMoreRelated {
                        ProgressView()
                            .onAppear {
                                loadMoreRelatedIllusts()
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                illustsGridView
            }
        }
        .frame(maxWidth: width)
        .padding(.bottom, 30)
        .onAppear {
            print("[IllustDetailRelatedSection] onAppear - relatedCount: \(relatedIllusts.count), isLoggedIn: \(isLoggedIn)")
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
        .frame(minHeight: 300)
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
        .frame(minHeight: 300)
    }

    private var emptyView: some View {
        HStack {
            Spacer()
            Text("暂无相关推荐")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(minHeight: 300)
    }

    private var illustsGridView: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            WaterfallGrid(
                data: filteredIllusts,
                columnCount: actualColumnCount,
                width: width - 24,
                aspectRatio: { $0.safeAspectRatio }
            ) { relatedIllust, columnWidth in
                NavigationLink(value: relatedIllust) {
                    RelatedIllustCard(illust: relatedIllust, showTitle: false, columnWidth: columnWidth)
                }
                .buttonStyle(.plain)
            }

            if hasMoreRelated {
                HStack {
                    Spacer()
                    if loadMoreError != nil {
                        Button {
                            loadMoreRelatedIllusts()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title2)
                                Text("加载失败，点击重试")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        ProgressView()
                            .id(relatedNextUrl)
                            .onAppear {
                                print("[IllustDetailRelatedSection] loadMore triggered - nextUrl: \(relatedNextUrl ?? "nil")")
                                loadMoreRelatedIllusts()
                            }
                    }
                    Spacer()
                }
                .padding(.vertical)
            } else if !filteredIllusts.isEmpty {
                Text(String(localized: "已经到底了"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            }
        }
        .padding(.horizontal, 12)
        .responsiveGridColumnCount(userSetting: settingStore.userSetting, columnCount: $dynamicColumnCount)
        .frame(minHeight: 300)
    }

    private func fetchRelatedIllusts() {
        print("[IllustDetailRelatedSection] fetchInitial called for id: \(illustId)")
        isLoadingRelated = true
        relatedIllustError = nil
        relatedNextUrl = nil
        hasMoreRelated = true

        Task {
            do {
                let result = try await PixivAPI.shared.getRelatedIllusts(illustId: illustId)
                print("[IllustDetailRelatedSection] API returned \(result.illusts.count) items, nextUrl: \(result.nextUrl ?? "nil")")
                await MainActor.run {
                    // 过滤掉当前插画
                    self.relatedIllusts = result.illusts.filter { $0.id != illustId }
                    self.relatedNextUrl = result.nextUrl
                    self.hasMoreRelated = result.nextUrl != nil
                    self.isLoadingRelated = false
                }
            } catch {
                print("[IllustDetailRelatedSection] API Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.relatedIllustError = error.localizedDescription
                    self.isLoadingRelated = false
                }
            }
        }
    }

    private func loadMoreRelatedIllusts() {
        guard let nextUrl = relatedNextUrl, !isFetchingMoreRelated && hasMoreRelated else {
            print("[IllustDetailRelatedSection] loadMore skipped: nextUrl=\(relatedNextUrl ?? "nil"), isFetching=\(isFetchingMoreRelated), hasMore=\(hasMoreRelated)")
            return
        }

        print("[IllustDetailRelatedSection] loadMore starting for nextUrl: \(nextUrl)")
        isFetchingMoreRelated = true
        loadMoreError = nil

        Task {
            do {
                let result = try await PixivAPI.shared.getIllustsByURL(nextUrl)
                print("[IllustDetailRelatedSection] loadMore returned \(result.illusts.count) items, nextUrl: \(result.nextUrl ?? "nil")")
                await MainActor.run {
                    // 过滤掉已存在的和当前的插画
                    let newIllusts = result.illusts.filter { new in
                        !self.relatedIllusts.contains(where: { $0.id == new.id }) && new.id != illustId
                    }
                    if newIllusts.isEmpty && result.nextUrl != nil {
                        print("[IllustDetailRelatedSection] all filtered, retrying next page")
                        self.relatedNextUrl = result.nextUrl
                        self.isFetchingMoreRelated = false
                        loadMoreRelatedIllusts()
                    } else {
                        self.relatedIllusts.append(contentsOf: newIllusts)
                        self.relatedNextUrl = result.nextUrl
                        self.hasMoreRelated = result.nextUrl != nil
                        self.isFetchingMoreRelated = false
                        print("[IllustDetailRelatedSection] Added \(newIllusts.count) items, total: \(relatedIllusts.count), nextUrl exists: \(hasMoreRelated)")
                    }
                }
            } catch {
                print("[IllustDetailRelatedSection] loadMore Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.loadMoreError = error.localizedDescription
                    self.isFetchingMoreRelated = false
                }
            }
        }
    }
}

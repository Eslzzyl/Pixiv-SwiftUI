import SwiftUI
import Observation
import Combine
import os.log

struct SauceNaoResultListView: View {
    let requestId: UUID
    @State private var store: SauceNaoResultListStore
    @Environment(UserSettingStore.self) private var settingStore
    @Environment(ThemeManager.self) private var themeManager

    init(requestId: UUID) {
        self.requestId = requestId
        self._store = State(initialValue: SauceNaoResultListStore(requestId: requestId))
    }

    private var filteredItems: [SauceNaoResultItem] {
        let visibleIllustIds = Set(settingStore.filterIllusts(store.items.map { $0.illust }).map { $0.id })
        return store.items.filter { visibleIllustIds.contains($0.illust.id) }
    }

    private var allDetailLoadsFailed: Bool {
        store.hasSearched && !store.matches.isEmpty && filteredItems.isEmpty && store.failedDetailCount > 0
    }

    var body: some View {
        GeometryReader { proxy in
            let dynamicColumnCount = ResponsiveGrid.columnCount(for: proxy.size.width, userSetting: settingStore.userSetting)
            let horizontalPadding: CGFloat = 24
            let availableWidth = proxy.size.width - horizontalPadding
            let waterfallWidth = availableWidth > 0 ? availableWidth : nil

            ZStack {
                if let error = store.error {
                    ContentUnavailableView(
                        "出错了",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.localizedDescription ?? "未知错误")
                    )
                } else if store.isLoading && filteredItems.isEmpty {
                    SkeletonIllustWaterfallGrid(
                        columnCount: dynamicColumnCount,
                        itemCount: 12,
                        width: waterfallWidth
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .transition(.opacity)
                } else if allDetailLoadsFailed {
                    ContentUnavailableView(
                        "未能加载可显示的插画",
                        systemImage: "wifi.exclamationmark",
                        description: Text("共匹配 \(store.matches.count) 条，详情加载失败 \(store.failedDetailCount) 条")
                    )
                } else if store.hasSearched && store.matches.isEmpty {
                    ContentUnavailableView(
                        "没有找到结果",
                        systemImage: "photo.badge.questionmark"
                    )
                } else if store.hasSearched && filteredItems.isEmpty {
                    ContentUnavailableView(
                        "没有可显示的结果",
                        systemImage: "exclamationmark.triangle"
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            WaterfallGrid(data: filteredItems, columnCount: dynamicColumnCount, width: waterfallWidth, aspectRatio: { $0.illust.safeAspectRatio }) { item, columnWidth in
                                IllustDetailNavigationLink(illust: item.illust, context: filteredItems.map(\.illust)) {
                                    SauceNaoResultWaterfallCard(
                                        item: item,
                                        columnCount: dynamicColumnCount,
                                        columnWidth: columnWidth,
                                        feedPreviewQuality: settingStore.userSetting.feedPreviewQuality,
                                        shouldBlur: settingStore.userSetting.shouldBlurIllust(item.illust),
                                        accentColor: themeManager.currentColor
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            if store.isLoading {
                                ProgressView()
                                    .padding(.vertical, 8)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: store.isLoading)
        }
        .navigationTitle("以图搜图")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await store.loadIfNeeded()
        }
    }
}

private struct SauceNaoResultWaterfallCard: View {
    let item: SauceNaoResultItem
    let columnCount: Int
    let columnWidth: CGFloat
    let feedPreviewQuality: Int
    let shouldBlur: Bool
    let accentColor: Color

    var body: some View {
        IllustCard(
            illust: item.illust,
            columnCount: columnCount,
            columnWidth: columnWidth,
            feedPreviewQuality: feedPreviewQuality,
            shouldBlur: shouldBlur,
            accentColor: accentColor
        )
        .overlay(alignment: .topTrailing) {
            Text(item.similarityTagText)
                .badgeStyle()
                .padding(6)
                .padding(.top, item.illust.pageCount > 1 ? 24 : 0)
                .allowsHitTesting(false)
        }
    }
}

@MainActor
@Observable
private final class SauceNaoResultListStore {
    var items: [SauceNaoResultItem] = []
    var matches: [SauceNaoMatch] = []
    var isLoading = false
    var hasSearched = false
    var error: AppError?
    var failedDetailCount = 0

    private let requestId: UUID
    private var hasLoaded = false
    private let api = SauceNAOAPI()

    init(requestId: UUID) {
        self.requestId = requestId
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        error = nil
        failedDetailCount = 0
        defer { isLoading = false }

        guard let request = SauceNaoSearchRequestStore.shared.consume(requestId: requestId) else {
            hasSearched = true
            error = AppError.networkError("请求已过期，请重新选择图片")
            return
        }

        do {
            let foundMatches = try await api.searchMatches(imageData: request.imageData, fileName: request.fileName)
            matches = foundMatches
            hasSearched = true
        } catch {
            hasSearched = true
            self.error = AppError.unknown(error)
            return
        }

        guard !matches.isEmpty else {
            return
        }

        for (index, match) in matches.enumerated() {
            // 检查任务是否被取消（例如由于视图消失）
            if Task.isCancelled { return }

            do {
                let illust = try await PixivAPI.shared.illustAPI.getIllustDetail(illustId: match.illustId)
                let item = SauceNaoResultItem(index: index, illust: illust, similarity: match.similarity)

                // 确保 UI 更新在主线程
                items.append(item)
            } catch {
                failedDetailCount += 1
                Logger.search.error("load illust failed: \(match.illustId), error: \(error.localizedDescription)")
            }
        }
    }
}

private struct SauceNaoResultItem: Identifiable, Equatable {
    let index: Int
    let illust: Illusts
    let similarity: Double?

    var id: Int { illust.id }

    static func == (lhs: SauceNaoResultItem, rhs: SauceNaoResultItem) -> Bool {
        lhs.index == rhs.index && lhs.illust.id == rhs.illust.id && lhs.similarity == rhs.similarity
    }

    var similarityTagText: String {
        guard let similarity else {
            return "--"
        }
        return String(format: "%.1f%%", similarity)
    }
}

#Preview {
    NavigationStack {
        SauceNaoResultListView(requestId: UUID())
    }
}

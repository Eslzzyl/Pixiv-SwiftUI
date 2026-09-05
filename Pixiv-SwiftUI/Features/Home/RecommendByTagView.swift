import SwiftUI
import os.log

struct RecommendByTagView: View {
    let target: RecommendByTagTarget
    @State private var illusts: [Illusts] = []
    @State private var isLoading = true
    @State private var fetchIndex: Int = 0
    @State private var hasMoreData = true
    @State private var errorMessage: String?
    @Environment(UserSettingStore.self) var settingStore
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.dismiss) private var dismiss
    @State private var prefetchTracker = PrefetchTracker()
    @State private var filteredIllusts: [Illusts] = []
    @State private var shouldBlurFlags: [Bool] = []

    private func recalculateFilteredIllusts() {
        filteredIllusts = settingStore.filterIllusts(illusts)
        shouldBlurFlags = filteredIllusts.map { settingStore.userSetting.shouldBlurIllust($0) }
    }

    private func shouldBlurFromCache(for illust: Illusts) -> Bool {
        guard let index = filteredIllusts.firstIndex(where: { $0.id == illust.id }),
              index < shouldBlurFlags.count
        else { return false }
        return shouldBlurFlags[index]
    }

    private var skeletonItemCount: Int {        #if os(macOS)
        32
        #else
        12
        #endif
    }

    var body: some View {
        GeometryReader { proxy in
            let dynamicColumnCount = ResponsiveGrid.columnCount(for: proxy.size.width, userSetting: settingStore.userSetting)
            let horizontalPadding: CGFloat = 24
            let availableWidth = proxy.size.width - horizontalPadding
            let waterfallWidth = availableWidth > 0 ? availableWidth : nil

            ScrollView {
                VStack(spacing: 0) {
                    if isLoading && illusts.isEmpty {
                        SkeletonIllustWaterfallGrid(
                            columnCount: dynamicColumnCount,
                            itemCount: skeletonItemCount,
                            width: waterfallWidth
                        )
                        .padding(.horizontal, 12)
                        .transition(.opacity)
                    } else if let error = errorMessage, illusts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text(error)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button(action: {
                                Task {
                                    await fetchIllusts(refresh: true)
                                }
                            }) {
                                Text(String(localized: "重试"))
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 64)
                    } else {
                        WaterfallGrid(data: filteredIllusts, columnCount: dynamicColumnCount, width: waterfallWidth, aspectRatio: { $0.safeAspectRatio }) { illust, columnWidth in
                            NavigationLink(value: illust) {
                                IllustCard(
                                    illust: illust,
                                    columnCount: dynamicColumnCount,
                                    columnWidth: columnWidth,
                                    feedPreviewQuality: settingStore.userSetting.feedPreviewQuality,
                                    shouldBlur: shouldBlurFromCache(for: illust),
                                    accentColor: themeManager.currentColor
                                )
                                .equatable()
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                prefetchIllustsIfNeeded(from: illust, in: filteredIllusts, quality: settingStore.userSetting.feedPreviewQuality, multiPagePrefetchCount: settingStore.userSetting.listMultiPagePrefetchCount, tracker: prefetchTracker)
                            }
                        }
                        .padding(.horizontal, 12)
                        .transition(.opacity)

                        if hasMoreData && !isLoading {
                            LazyVStack {
                                ProgressView()
                                    #if os(macOS)
                                    .controlSize(.small)
                                    #endif
                                    .padding()
                                    .id(fetchIndex)
                                    .onAppear {
                                        Task {
                                            await loadMoreData()
                                        }
                                    }
                            }
                        } else if !filteredIllusts.isEmpty {
                            Text(String(localized: "已经到底了"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isLoading)
        }
        .task {
            if illusts.isEmpty {
                await fetchIllusts(refresh: true)
            }
        }
        .onFilterSettingsChange(from: settingStore, perform: recalculateFilteredIllusts)
        .navigationTitle(target.tag)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem {
                NavigationLink(value: SearchResultTarget(word: target.tag)) {
                    #if os(macOS)
                    Label(String(localized: "搜索该标签"), systemImage: "magnifyingglass")
                    #else
                    Image(systemName: "magnifyingglass")
                    #endif
                }
            }
            #if os(macOS)
            ToolbarItem {
                RefreshButton(refreshAction: { await fetchIllusts(refresh: true) })
            }
            #endif
        }
        .task {
            if illusts.isEmpty {
                await fetchIllusts(refresh: true)
            }
        }
    }

    private func fetchIllusts(refresh: Bool = false) async {
        if refresh {
            illusts = []
            recalculateFilteredIllusts()
            fetchIndex = 0
            hasMoreData = true
            errorMessage = nil
            isLoading = true
        } else if isLoading {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let idsToFetch = Array(target.illustIds.prefix(10))
            if idsToFetch.isEmpty {
                hasMoreData = false
                return
            }

// Fetch sequentially since SwiftData models aren't Sendable
            var results: [Illusts] = []
            for id in idsToFetch {
                if let detail = try? await PixivAPI.shared.illustAPI.getIllustDetail(illustId: id) {
                    results.append(detail)
                }
            }
            illusts = results
            recalculateFilteredIllusts()

            fetchIndex = idsToFetch.count
            hasMoreData = fetchIndex < target.illustIds.count
        } catch {
            errorMessage = error.localizedDescription
            Logger.illust.error("Failed to fetch recommended illusts for tag \(target.tag): \(error)")
        }
    }

    private func loadMoreData() async {
        guard !isLoading && hasMoreData else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let nextIndex = min(fetchIndex + 10, target.illustIds.count)
            let idsToFetch = Array(target.illustIds[fetchIndex..<nextIndex])

            if idsToFetch.isEmpty {
                hasMoreData = false
                return
            }

            // Fetch sequentially
            var newIllusts: [Illusts] = []
            for id in idsToFetch {
                if let detail = try? await PixivAPI.shared.illustAPI.getIllustDetail(illustId: id) {
                    newIllusts.append(detail)
                }
            }

            illusts.append(contentsOf: newIllusts)
            recalculateFilteredIllusts()
            fetchIndex = nextIndex
            hasMoreData = fetchIndex < target.illustIds.count
        } catch {
            Logger.illust.error("Failed to load more recommended illusts for tag \(target.tag): \(error)")
        }
    }
}

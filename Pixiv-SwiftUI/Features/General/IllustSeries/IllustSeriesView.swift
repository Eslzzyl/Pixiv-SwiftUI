import SwiftUI

struct IllustSeriesView: View {
    @Environment(ThemeManager.self) var themeManager
    let seriesId: Int
    @State private var store: IllustSeriesStore
    @State private var dynamicColumnCount: Int = ResponsiveGrid.initialColumnCount(userSetting: UserSettingStore.shared.userSetting)
    @Environment(UserSettingStore.self) var settingStore

    init(seriesId: Int) {
        self.seriesId = seriesId
        self._store = State(initialValue: IllustSeriesStore(seriesId: seriesId))
    }

    private var filteredIllusts: [Illusts] {
        settingStore.filterIllusts(store.illusts)
    }

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = max(proxy.size.width, 1)
            ScrollView {
                Group {
                    if store.isLoading && store.seriesDetail == nil {
                        loadingView
                            .transition(.opacity)
                    } else if let error = store.error {
                        errorView(error.localizedDescription ?? "未知错误")
                    } else if let detail = store.seriesDetail {
                        content(detail, viewportWidth: viewportWidth)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: store.isLoading && store.seriesDetail == nil)
            }
            .navigationTitle(store.seriesDetail?.title ?? String(localized: "系列详情"))
            .task {
                guard store.seriesDetail == nil else { return }
                await store.fetch()
            }
            .refreshable {
                await store.fetch()
            }
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Cover image skeleton
            SkeletonRoundedRectangle(height: 200, cornerRadius: 12)

            // Title skeleton
            SkeletonView(height: 22, width: 200, cornerRadius: 4)

            // Caption skeleton
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(height: 12, width: nil, cornerRadius: 4)
                SkeletonView(height: 12, width: 180, cornerRadius: 4)
            }

            // User info skeleton
            HStack(spacing: 12) {
                SkeletonCircle(size: 24)
                SkeletonView(height: 14, width: 80, cornerRadius: 4)
                SkeletonView(height: 14, width: 60, cornerRadius: 4)
            }

            Divider()
                .padding(.vertical, 4)

            // Waterfall grid skeleton
            SkeletonIllustWaterfallGrid(
                columnCount: dynamicColumnCount,
                itemCount: 12
            )
            .padding(.horizontal, 12)
        }
        .padding()
        .transition(.opacity)
    }

    @ViewBuilder
    private func errorView(_ error: String) -> some View {
        ErrorStateView(message: error, retryAction: {
            Task {
                await store.fetch()
            }
        })
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    @ViewBuilder
    private func content(_ detail: IllustSeriesDetail, viewportWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            seriesHeader(detail)

            Divider()
                .padding(.vertical, 8)

            // Illust grid
            if filteredIllusts.isEmpty && !store.illusts.isEmpty {
                emptyFilterView
            } else {
                WaterfallGrid(
                    data: filteredIllusts,
                    columnCount: dynamicColumnCount,
                    width: viewportWidth - 24,
                    aspectRatio: { $0.safeAspectRatio }
                ) { illust, columnWidth in
                    let index = filteredIllusts.firstIndex(where: { $0.id == illust.id }) ?? 0
                    NavigationLink(value: illust) {
                        IllustCard(
                            illust: illust,
                            columnCount: dynamicColumnCount,
                            columnWidth: columnWidth,
                            feedPreviewQuality: settingStore.userSetting.feedPreviewQuality,
                            accentColor: themeManager.currentColor,
                            seriesNumber: index + 1
                        )
                        .equatable()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .responsiveGridColumnCount(userSetting: settingStore.userSetting, columnCount: $dynamicColumnCount)

                // Load more
                if store.nextUrl != nil {
                    LazyVStack {
                        ProgressView()
                            #if os(macOS)
                            .controlSize(.small)
                            #endif
                            .padding()
                            .onAppear {
                                Task {
                                    await store.loadMore()
                                }
                            }
                    }
                } else if !store.illusts.isEmpty {
                    Text(String(localized: "已经到底了"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
        }
    }

    @ViewBuilder
    private var emptyFilterView: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(String(localized: "已根据您的设置过滤掉所有插画"))
                .font(.headline)
                .foregroundColor(.secondary)
            Text(String(localized: "尝试调整过滤设置以查看更多内容"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }

    @ViewBuilder
    private func seriesHeader(_ detail: IllustSeriesDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageUrl = detail.coverImageUrls?.medium, !imageUrl.isEmpty {
                // coverImageUrls.medium 是 CDN 按横幅裁剪好的图片（约 782×410 ≈ 1.9:1），
                // detail.width/detail.height 是原始尺寸，与裁剪后的图片不匹配，因此使用固定比例
                CachedAsyncImage(
                    urlString: imageUrl,
                    aspectRatio: 1.9,
                    contentMode: .fill
                )
                .frame(maxWidth: .infinity)
                .clipped()
                .cornerRadius(12)
            }

            Text(detail.title)
                .font(.title2)
                .fontWeight(.bold)

            if let caption = detail.caption, !caption.isEmpty {
                Text(caption)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                let user = User(
                    profileImageUrls: detail.user.profileImageUrls.toDomain(),
                    id: detail.user.id,
                    name: detail.user.name,
                    account: detail.user.account
                )
                NavigationLink(value: user) {
                    HStack(spacing: 8) {
                        AnimatedAvatarImage(urlString: detail.user.profileImageUrls.medium, size: 24)
                        Text(detail.user.name)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }

                Text("•")
                    .foregroundColor(.secondary)

                Text("\(detail.seriesWorkCount) 部作品")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let latestIllust = filteredIllusts.first {
                NavigationLink(value: latestIllust) {
                    Label("查看最新作品", systemImage: "arrow.right.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.currentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                #if os(macOS)
                .buttonStyle(.plain)
                #endif
            }
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        IllustSeriesView(seriesId: 1)
    }
}

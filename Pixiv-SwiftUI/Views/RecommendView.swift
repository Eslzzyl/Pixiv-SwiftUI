import SwiftUI

/// 推荐页面
struct RecommendView: View {
    @State private var illusts: [Illusts] = []
    @State private var isLoading = false
    @State private var nextUrl: String?
    @State private var hasMoreData = true
    @State private var error: String?
    @Environment(UserSettingStore.self) var settingStore
    @State private var path = NavigationPath()
    
    private var columnCount: Int {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad ? settingStore.userSetting.hCrossCount : settingStore.userSetting.crossCount
        #else
        settingStore.userSetting.hCrossCount
        #endif
    }
    
    private var filteredIllusts: [Illusts] {
        settingStore.filterIllusts(illusts)
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                VStack(spacing: 0) {
                    if illusts.isEmpty && isLoading {
                        VStack {
                            ProgressView()
                            Text("加载中...")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if illusts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("没有加载到推荐内容")
                                .foregroundColor(.gray)
                            Button(action: loadMoreData) {
                                Text("重新加载")
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            WaterfallGrid(data: filteredIllusts, columnCount: columnCount) { illust, columnWidth in
                                NavigationLink(value: illust) {
                                    IllustCard(illust: illust, columnCount: columnCount, columnWidth: columnWidth, expiration: DefaultCacheExpiration.recommend)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            
                            if hasMoreData {
                                ProgressView()
                                    .padding()
                                    .id(nextUrl)
                                    .onAppear {
                                        loadMoreData()
                                    }
                            }
                        }
                    }
                    
                    if let error = error {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(error)
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                            
                            Button(action: loadMoreData) {
                                Text("重试")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                    }
                }
                #if os(macOS)
                .background(Color(nsColor: .windowBackgroundColor))
                #else
                .background(Color(uiColor: .systemGroupedBackground))
                #endif
            }
            .navigationTitle("推荐")
            .navigationDestination(for: Illusts.self) { illust in
                IllustDetailView(illust: illust)
            }
            .navigationDestination(for: User.self) { user in
                UserDetailView(userId: user.id.stringValue)
            }
            .onAppear {
                if illusts.isEmpty && !isLoading {
                    loadMoreData()
                }
            }
        }
    }
    
    private func loadMoreData() {
        guard !isLoading, hasMoreData else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                let result: (illusts: [Illusts], nextUrl: String?)
                if let next = nextUrl {
                    result = try await PixivAPI.shared.getIllustsByURL(next)
                } else {
                    result = try await PixivAPI.shared.getRecommendedIllusts()
                }
                
                await MainActor.run {
                    illusts.append(contentsOf: result.illusts)
                    nextUrl = result.nextUrl
                    hasMoreData = result.nextUrl != nil
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    RecommendView()
}

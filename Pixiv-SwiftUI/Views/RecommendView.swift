import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// 推荐页面
struct RecommendView: View {
    @State private var illusts: [Illusts] = []
    @State private var isLoading = false
    @State private var offset = 0
    @State private var hasMoreData = true
    @State private var error: String?
    @Environment(UserSettingStore.self) var settingStore
    
    private var columnCount: Int {
        let screenWidth: CGFloat
        #if canImport(UIKit)
        screenWidth = UIScreen.main.bounds.width
        #else
        screenWidth = NSScreen.main?.frame.width ?? 800
        #endif
        let isPortrait = screenWidth < 800
        return isPortrait ? settingStore.userSetting.crossCount : settingStore.userSetting.hCrossCount
    }
    
    private var filteredIllusts: [Illusts] {
        if settingStore.userSetting.r18DisplayMode == 2 {
            return illusts.filter { $0.xRestrict < 1 }
        }
        return illusts
    }
    
    var body: some View {
        NavigationStack {
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
                            WaterfallGrid(data: filteredIllusts, columnCount: columnCount, onLoadMore: checkLoadMore) { illust in
                                NavigationLink(destination: IllustDetailView(illust: illust)) {
                                    IllustCard(illust: illust, columnCount: columnCount)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if isLoading {
                                ProgressView()
                                    .padding()
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
                .background(Color(white: 0.97))
            }
            .onAppear {
                if illusts.isEmpty {
                    loadMoreData()
                }
            }
        }
    }
    
    private func checkLoadMore(for illust: Illusts) {
        guard hasMoreData && !isLoading else { return }
        
        let list = filteredIllusts
        let thresholdIndex = list.index(list.endIndex, offsetBy: -5, limitedBy: list.startIndex) ?? 0
        
        if let illustIndex = list.firstIndex(where: { $0.id == illust.id }),
           illustIndex >= thresholdIndex {
            loadMoreData()
        }
    }
    
    private func loadMoreData() {
        guard !isLoading, hasMoreData else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                let newIllusts = try await PixivAPI.shared.getRecommendedIllusts(
                    offset: offset,
                    limit: 30
                )
                
                await MainActor.run {
                    illusts.append(contentsOf: newIllusts)
                    offset += 30
                    hasMoreData = !newIllusts.isEmpty
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

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// 推荐页面
struct RecommendView: View {
    @State private var illusts: [Illusts] = []
    @State private var isLoading = false
    @State private var nextUrl: String?
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
        var result = illusts
        if settingStore.userSetting.r18DisplayMode == 2 {
            result = result.filter { $0.xRestrict < 1 }
        }
        if settingStore.userSetting.blockAI {
            result = result.filter { $0.illustAIType != 2 }
        }
        return result
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
                            WaterfallGrid(data: filteredIllusts, columnCount: columnCount) { illust in
                                NavigationLink(destination: IllustDetailView(illust: illust)) {
                                    IllustCard(illust: illust, columnCount: columnCount)
                                }
                                .buttonStyle(.plain)
                            }
                            
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
            .onAppear {
                if illusts.isEmpty {
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

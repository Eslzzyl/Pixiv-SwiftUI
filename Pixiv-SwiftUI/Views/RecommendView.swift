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
    @State private var settingStore = UserSettingStore()
    
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
    
    private var columns: [[Illusts]] {
        (0..<columnCount).map { columnIndex in
            Array(illusts.enumerated().filter { $0.offset % columnCount == columnIndex }.map { $0.element })
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Text("推荐")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(Color(white: 0.97))
                .border(Color.gray.opacity(0.2), width: 0.5)
                
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
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(0..<columns.count, id: \.self) { columnIndex in
                                LazyVStack(spacing: 12) {
                                    ForEach(columns[columnIndex], id: \.id) { illust in
                                        IllustCard(illust: illust, columnCount: columnCount)
                                            .onAppear {
                                                checkLoadMore(for: illust)
                                            }
                                    }
                                }
                            }
                        }
                        .padding(12)
                        
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
    
    private func checkLoadMore(for illust: Illusts) {
        guard hasMoreData && !isLoading else { return }
        
        let thresholdIndex = illusts.index(illusts.endIndex, offsetBy: -5, limitedBy: illusts.startIndex) ?? 0
        
        if let illustIndex = illusts.firstIndex(where: { $0.id == illust.id }),
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

import SwiftUI

/// 推荐页面
struct RecommendView: View {
    @State private var illusts: [Illusts] = []
    @State private var isLoading = false
    @State private var offset = 0
    @State private var hasMoreData = true
    @State private var error: String?

    private let columns = [
        GridItem(.flexible(minimum: 100), spacing: 12),
        GridItem(.flexible(minimum: 100), spacing: 12),
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 导航栏
                HStack {
                    Text("推荐")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(Color(white: 0.97))
                .border(Color.gray.opacity(0.2), width: 0.5)

                // 内容区域
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
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(illusts, id: \.id) { illust in
                                IllustCard(illust: illust)
                                    .onAppear {
                                        // 当接近列表末尾时加载更多
                                        if illust.id == illusts.last?.id, hasMoreData && !isLoading
                                        {
                                            loadMoreData()
                                        }
                                    }
                            }
                        }
                        .padding(12)

                        // 加载更多指示
                        if isLoading {
                            ProgressView()
                                .padding()
                        }
                    }
                }

                // 错误提示
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

    /// 加载更多推荐插画
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

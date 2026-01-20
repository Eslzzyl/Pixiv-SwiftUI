import SwiftUI
import Combine

struct NovelListPage: View {
    let listType: NovelListType
    @StateObject private var store = NovelStore()
    @State private var path = NavigationPath()
    @State private var novels: [Novel] = []
    @State private var nextUrl: String?
    @State private var isLoading = false
    var accountStore: AccountStore = AccountStore.shared
    @Environment(UserSettingStore.self) private var settingStore
    
    private var isLoadingMore: Bool {
        isLoading && !novels.isEmpty
    }
    
    private var filteredNovels: [Novel] {
        settingStore.filterNovels(novels)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isLoading && novels.isEmpty {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { _ in
                            SkeletonNovelListCard()
                        }
                    }
                    .padding(.horizontal, 12)
                } else if novels.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("暂无内容")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 50)
                } else {
                    ForEach(filteredNovels) { novel in
                        NavigationLink(value: novel) {
                            NovelListCard(novel: novel)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if novel.id == filteredNovels.last?.id {
                                Task {
                                    await loadMore()
                                }
                            }
                        }
                    }
                }

                if nextUrl != nil {
                    ProgressView()
                        .padding()
                        .id(nextUrl)
                        .onAppear {
                            Task {
                                await loadMore()
                            }
                        }
                }
            }
        }
        .refreshable {
            await refresh()
        }
        .navigationTitle(listType.title)
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        let result = await store.load(listType: listType, forceRefresh: false)
        novels = result.novels
        nextUrl = result.nextUrl
    }

    private func refresh() async {
        let result = await store.load(listType: listType, forceRefresh: true)
        novels = result.novels
        nextUrl = result.nextUrl
    }

    private func loadMore() async {
        guard let url = nextUrl, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        let result = await store.loadMore(listType: listType, url: url)
        novels.append(contentsOf: result.novels)
        nextUrl = result.nextUrl
    }
}

#Preview {
    NavigationStack {
        NovelListPage(listType: .recommend)
    }
}

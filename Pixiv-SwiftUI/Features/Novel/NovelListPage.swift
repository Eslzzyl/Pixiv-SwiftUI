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

    @State private var selectedRestrict: TypeFilterButton.RestrictType? = .publicAccess
    @State private var initialRestrict: String = "public"

    private var isLoadingMore: Bool {
        isLoading && !novels.isEmpty
    }

    private var filteredNovels: [Novel] {
        settingStore.filterNovels(novels)
    }

    private var shouldShowRestrictFilter: Bool {
        switch listType {
        case .bookmarks, .following:
            return true
        case .recommend:
            return false
        }
    }

    private var effectiveRestrict: String {
        switch listType {
        case .bookmarks, .following:
            return selectedRestrict == .privateAccess ? "private" : "public"
        case .recommend:
            return "public"
        }
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
                        Text("暂无\(listType.title)")
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
                        #if os(macOS)
                        .controlSize(.small)
                        #endif
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
            await refresh(forceRefresh: true)
        }
        .keyboardShortcut("r", modifiers: .command)
        .navigationTitle(listType.title)
        .toolbar {
            if shouldShowRestrictFilter {
                ToolbarItem {
                    TypeFilterButton(
                        selectedType: .constant(.all),
                        restrict: .publicAccess,
                        selectedRestrict: $selectedRestrict,
                        showContentTypes: false
                    )
                    .menuIndicator(.hidden)
                }
            }
            #if os(macOS)
            ToolbarItem {
                RefreshButton(refreshAction: { await refresh(forceRefresh: true) })
            }
            #endif
        }
        .onChange(of: selectedRestrict) { _, _ in
            Task {
                await refresh()
            }
        }
        .task {
            await loadData()
        }
        .onChange(of: accountStore.currentUserId) { _, _ in
            Task {
                await refresh()
            }
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        let result = await store.load(listType: listType, restrict: effectiveRestrict, forceRefresh: false)
        novels = result.novels
        nextUrl = result.nextUrl
    }

    private func refresh(forceRefresh: Bool = false) async {
        let result = await store.load(listType: listType, restrict: effectiveRestrict, forceRefresh: forceRefresh)
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

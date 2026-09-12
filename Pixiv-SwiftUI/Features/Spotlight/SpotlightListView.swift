import SwiftUI

struct SpotlightListView: View {
    @State private var store = SpotlightStore()
    @State private var navigateToDetail: SpotlightArticle?

    @State private var searchText: String = ""
    @State private var isSearchEditing: Bool = false

    #if os(macOS)
    @State private var columnCount: Int = 4
    #else
    @State private var columnCount: Int = 2
    #endif

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                searchSection

                if isSearchEditing && !store.searchHistory.isEmpty {
                    SpotlightSearchHistory(
                        history: store.searchHistory,
                        onSelect: { query in
                            searchText = query
                            isSearchEditing = false
                            #if os(macOS)
                            // On macOS, the focus from searchable is not manually controlled here
                            #endif
                            Task {
                                await store.search(query)
                            }
                        },
                        onRemove: { query in
                            store.removeFromHistory(query)
                        },
                        onClear: {
                            store.clearHistory()
                        }
                    )
                } else {
                    articleGrid
                }
            }
        }
        .navigationTitle(store.source.isSearch ? "" : String(localized: "亮点"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(store.source.isSearch ? .inline : .automatic)
        #endif
        #if os(macOS)
        .searchable(text: $searchText, placement: .toolbar, prompt: String(localized: "搜索特辑")) {
            if !store.searchHistory.isEmpty {
                ForEach(store.searchHistory, id: \.self) { query in
                    Label(query, systemImage: "clock.arrow.circlepath")
                        .searchCompletion(query)
                }
            }
        }
        .onSubmit(of: .search) {
            Task {
                await store.search(searchText)
            }
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                Task {
                    await store.clearSearch()
                }
            }
        }
        #endif
        .task {
            if store.articles.isEmpty {
                await store.fetch()
            }
        }
        .refreshable {
            await store.fetch(forceRefresh: true)
        }
        .navigationDestination(item: $navigateToDetail) { article in
            SpotlightDetailView(article: article)
        }
    }

    private var searchSection: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            SpotlightSearchBar(
                text: $searchText,
                isEditing: $isSearchEditing,
                onSubmit: { query in
                    Task {
                        await store.search(query)
                    }
                },
                onCancel: {
                    searchText = ""
                    Task {
                        await store.clearSearch()
                    }
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, isSearchEditing ? 0 : 12)
            #endif

            if store.source.isSearch {
                HStack {
                    Text(store.source.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    if store.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private var articleGrid: some View {
        if store.isLoading && store.articles.isEmpty {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<(columnCount * 2), id: \.self) { _ in
                    skeletonCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .transition(.opacity.animation(.easeInOut(duration: 0.25)))
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(store.articles) { article in
                    Button {
                        navigateToDetail = article
                    } label: {
                        SpotlightListCard(article: article)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if article.id == store.articles.last?.id {
                            Task {
                                await store.loadMore()
                            }
                        }
                    }
                }

                if store.isLoadingMore {
                    ForEach(0..<columnCount, id: \.self) { _ in
                        skeletonCard
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .transition(.opacity.animation(.easeInOut(duration: 0.25)))
        }
    }

    private var skeletonCard: some View {
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(1.9, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .skeleton()

                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 2) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 16)
                            .skeleton()
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 180, height: 16)
                            .skeleton()
                    }

                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 10)
                    .skeleton()
            }
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    NavigationStack {
        SpotlightListView()
    }
}

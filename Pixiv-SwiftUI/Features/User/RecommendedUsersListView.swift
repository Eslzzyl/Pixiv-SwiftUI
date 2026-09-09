import SwiftUI

struct RecommendedUsersListView: View {
    var store: RecommendedUsersStore
    @State private var isRefreshing: Bool = false
    @Environment(ThemeManager.self) var themeManager

    @State private var columnCount: Int = 1

    init(store: RecommendedUsersStore = RecommendedUsersStore()) {
        self.store = store
    }

    var body: some View {
        ScrollView {
            Group {
                if store.isLoading && store.users.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount), spacing: 16) {
                        ForEach(0..<skeletonItemCount, id: \.self) { _ in
                            SkeletonUserCard()
                        }
                    }
                    .padding()
                    .transition(.opacity)
                } else if store.users.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text(String(localized: "暂无推荐画师"))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                    .transition(.opacity)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount), spacing: 16) {
                        ForEach(store.users) { preview in
                            NavigationLink(value: PixivNavigationRoute.user(id: preview.user.id.stringValue)) {
                                UserPreviewCard(userPreview: preview, accentColor: themeManager.currentColor)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if preview.id == store.users.last?.id && store.nextUrl != nil {
                                    Task {
                                        await store.loadMoreUsers()
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .transition(.opacity)

                    if store.nextUrl != nil {
                        ProgressView()
                            #if os(macOS)
                            .controlSize(.small)
                            #endif
                            .padding()
                    } else if !store.users.isEmpty {
                        HStack {
                            Spacer()
                            Text(String(localized: "已经到底了"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.isLoading)
        .refreshable {
            isRefreshing = true
            await store.refreshUsers()
            isRefreshing = false
        }
        .responsiveUserGridColumnCount(columnCount: $columnCount)
        .onReceive(NotificationCenter.default.publisher(for: .refreshCurrentPage)) { _ in
            Task { @MainActor in
                isRefreshing = true
                await store.refreshUsers()
                isRefreshing = false
            }
        }
        .navigationTitle(String(localized: "推荐画师"))
        .sensoryFeedback(.impact(weight: .medium), trigger: isRefreshing)
        #if os(macOS)
        .toolbar {
            ToolbarItem {
                RefreshButton(refreshAction: {
                    isRefreshing = true
                    await store.refreshUsers()
                    isRefreshing = false
                })
            }
        }
        #endif
        .onAppear {
            if store.users.isEmpty {
                Task {
                    await store.fetchUsers()
                }
            }
        }
    }

    private var skeletonItemCount: Int {
        #if os(macOS)
        12
        #else
        6
        #endif
    }
}

#Preview {
    NavigationStack {
        RecommendedUsersListView()
    }
}

import SwiftUI

struct FollowingListView: View {
    @StateObject var store: FollowingListStore
    @State private var isRefreshing: Bool = false
    let userId: String

    @State private var columnCount: Int = 1
    @State private var selectedRestrict: TypeFilterButton.RestrictType? = .publicAccess

    private var restrictString: String {
        selectedRestrict == .privateAccess ? "private" : "public"
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount), spacing: 16) {
                ForEach(store.following) { preview in
                    NavigationLink(value: preview.user) {
                        UserPreviewCard(userPreview: preview)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if preview.id == store.following.last?.id && store.nextUrlFollowing != nil {
                            Task {
                                await store.loadMoreFollowing()
                            }
                        }
                    }
                }
            }
            .padding()

            if store.nextUrlFollowing != nil {
                ProgressView()
                    #if os(macOS)
                    .controlSize(.small)
                    #endif
                    .padding()
            } else if !store.following.isEmpty {
                Text(String(localized: "已经到底了"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .refreshable {
            isRefreshing = true
            await store.refreshFollowing(userId: userId, restrict: restrictString)
            isRefreshing = false
        }
        .keyboardShortcut("r", modifiers: .command)
        .responsiveUserGridColumnCount(columnCount: $columnCount)
        .navigationTitle("关注")
        .sensoryFeedback(.impact(weight: .medium), trigger: isRefreshing)
        .toolbar {
            ToolbarItem {
                TypeFilterButton(
                    selectedType: .constant(.all),
                    restrict: .publicAccess,
                    selectedRestrict: $selectedRestrict,
                    showContentTypes: false,
                    cacheFilter: .constant(nil)
                )
                .menuIndicator(.hidden)
            }
            #if os(macOS)
            ToolbarItem {
                RefreshButton(refreshAction: {
                    isRefreshing = true
                    await store.refreshFollowing(userId: userId, restrict: restrictString)
                    isRefreshing = false
                })
            }
            #endif
        }
        .onChange(of: selectedRestrict) { _, _ in
            Task {
                await store.refreshFollowing(userId: userId, restrict: restrictString)
            }
        }
        .onAppear {
            if store.following.isEmpty {
                Task {
                    await store.fetchFollowing(userId: userId, restrict: restrictString)
                }
            }
        }
    }
}

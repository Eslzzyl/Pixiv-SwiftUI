import SwiftUI

struct FollowingListView: View {
    @StateObject var store: FollowingListStore
    @State private var isRefreshing: Bool = false
    let userId: String

    @State private var columnCount: Int = 1

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount), spacing: 16) {
                ForEach(store.following) { preview in
                    NavigationLink(value: preview.user) {
                        UserPreviewCard(userPreview: preview)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if preview.id == store.following.last?.id {
                            Task {
                                await store.loadMoreFollowing()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable {
            isRefreshing = true
            await store.fetchFollowing(userId: userId)
            isRefreshing = false
        }
        .responsiveUserGridColumnCount(columnCount: $columnCount)
        .navigationTitle("关注")
        .sensoryFeedback(.impact(weight: .medium), trigger: isRefreshing)
        .onAppear {
            if store.following.isEmpty {
                Task {
                    await store.fetchFollowing(userId: userId)
                }
            }
        }
    }
}

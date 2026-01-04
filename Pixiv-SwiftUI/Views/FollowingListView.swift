import SwiftUI

struct FollowingListView: View {
    @StateObject var store: FollowingListStore
    @State private var isRefreshing: Bool = false
    let userId: String

    var body: some View {
        List(store.following) { preview in
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
        .listStyle(.plain)
        .refreshable {
            isRefreshing = true
            await store.fetchFollowing(userId: userId)
            isRefreshing = false
        }
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

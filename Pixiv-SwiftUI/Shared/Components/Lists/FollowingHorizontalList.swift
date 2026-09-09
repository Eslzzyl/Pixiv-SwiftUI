import SwiftUI

struct FollowingHorizontalList: View {
    var store: UpdatesStore
    @Environment(\.pixivNavigationRouter) private var navigationRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    navigationRouter?.push(.followingList(userID: AccountStore.shared.currentUserId))
                } label: {
                    HStack(spacing: 4) {
                        Text("已关注")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)

            if store.following.isEmpty && (store.isLoadingFollowing || !store.hasFetchedFollowing) {
                SkeletonUserHorizontalList(itemCount: 6)
                    .transition(.opacity)
            } else if store.following.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无关注用户")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.following.prefix(10)) { preview in
                            NavigationLink(value: PixivNavigationRoute.user(id: preview.user.id.stringValue)) {
                                VStack(spacing: 4) {
                                    AnimatedAvatarImage(
                                        urlString: preview.user.profileImageUrls?.medium,
                                        size: 48,
                                        expiration: DefaultCacheExpiration.userAvatar
                                    )

                                    Text(preview.user.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 60)
                            }
                            .buttonStyle(.plain)
                        }

                        NavigationLink(value: PixivNavigationRoute.followingList(userID: AccountStore.shared.currentUserId)) {
                            VStack(spacing: 4) {
                                Image(systemName: "ellipsis")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("查看全部")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 60)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.isLoadingFollowing)
    }
}

import SwiftUI

struct FollowingHorizontalList: View {
    @ObservedObject var store: UpdatesStore
    @Binding var path: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    path.append("followingList")
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

            if store.following.isEmpty && store.isLoadingFollowing {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
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
                            NavigationLink(value: preview.user) {
                                VStack(spacing: 4) {
                                    CachedAsyncImage(
                                        urlString: preview.user.profileImageUrls?.medium,
                                        expiration: DefaultCacheExpiration.userAvatar
                                    )
                                    .frame(width: 48, height: 48)
                                    .clipShape(Circle())

                                    Text(preview.user.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 60)
                            }
                            .buttonStyle(.plain)
                        }

                        NavigationLink(value: "followingList" as String) {
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
            }
        }
    }
}

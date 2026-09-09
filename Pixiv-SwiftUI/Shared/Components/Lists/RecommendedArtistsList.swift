import SwiftUI

struct RecommendedArtistsList: View {
    @Binding var recommendedUsers: [UserPreviews]
    @Binding var isLoadingRecommended: Bool
    @Environment(\.pixivNavigationRouter) private var navigationRouter
    var onRefresh: (() async -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    navigationRouter?.push(.recommendedArtists)
                } label: {
                    HStack(spacing: 4) {
                        Text("画师")
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

            if isLoadingRecommended && recommendedUsers.isEmpty {
                SkeletonUserHorizontalList(itemCount: 6)
                    .transition(.opacity)
            } else if recommendedUsers.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无推荐画师")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recommendedUsers.prefix(10)) { preview in
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

                        NavigationLink(value: PixivNavigationRoute.recommendedArtists) {
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
        .animation(.easeInOut(duration: 0.25), value: isLoadingRecommended)
    }
}

#Preview {
    NavigationStack {
        RecommendedArtistsList(
            recommendedUsers: .constant([
                UserPreviews(
                    user: UserDTO(
                        profileImageUrls: ProfileImageUrlsDTO(px16x16: "", px50x50: "", px170x170: "", medium: "https://i.pixiv.cat/img/user-img/1/1.jpg"),
                        id: .string("1"),
                        name: "测试用户",
                        account: "test_user",
                        mailAddress: nil,
                        isPremium: nil,
                        xRestrict: nil,
                        isMailAuthorized: nil,
                        requirePolicyAgreement: nil,
                        isAcceptRequest: nil,
                        isFollowed: nil
                    ),
                    illusts: [],
                    novels: [],
                    isMuted: false
                )
            ]),
            isLoadingRecommended: .constant(false)
        )
    }
}

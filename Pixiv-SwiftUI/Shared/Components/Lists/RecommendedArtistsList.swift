import SwiftUI

struct RecommendedArtistsList: View {
    @Binding var recommendedUsers: [UserPreviews]
    @Binding var isLoadingRecommended: Bool
    var onRefresh: (() async -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("画师")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)

            if isLoadingRecommended && recommendedUsers.isEmpty {
                SkeletonUserHorizontalList(itemCount: 6)
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
                            NavigationLink(value: preview.user) {
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
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecommendedArtistsList(
            recommendedUsers: .constant([
                UserPreviews(
                    user: User(
                        profileImageUrls: ProfileImageUrls(px16x16: "", px50x50: "", px170x170: "", medium: "https://i.pixiv.cat/img/user-img/1/1.jpg"),
                        id: .string("1"),
                        name: "测试用户",
                        account: "test_user"
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

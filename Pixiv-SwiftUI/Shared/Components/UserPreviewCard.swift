import SwiftUI

struct UserPreviewCard: View {
    let userPreview: UserPreviews
    @Environment(ThemeManager.self) var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 用户信息行
            HStack(spacing: 12) {
                CachedAsyncImage(
                    urlString: userPreview.user.profileImageUrls?.medium,
                    placeholder: AnyView(Circle().fill(Color.secondary.opacity(0.1))),
                    expiration: DefaultCacheExpiration.userAvatar
                )
                .frame(width: 44, height: 44)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(userPreview.user.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Text("@\(userPreview.user.account)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let isFollowed = userPreview.user.isFollowed {
                    Image(systemName: isFollowed ? "person.badge.minus" : "person.badge.plus")
                        .font(.system(size: 14))
                        .foregroundColor(isFollowed ? .secondary : themeManager.currentColor)
                        .padding(8)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 4)

            // 作品预览行
            HStack(spacing: 6) {
                if !userPreview.illusts.isEmpty {
                    ForEach(userPreview.illusts.prefix(3)) { illust in
                        CachedAsyncImage(urlString: illust.imageUrls.squareMedium)
                            .aspectRatio(1, contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .clipped()
                            .cornerRadius(6)
                    }

                    // 补充空白槽位，保持布局整齐
                    if userPreview.illusts.count < 3 {
                        ForEach(0..<(3 - userPreview.illusts.count), id: \.self) { _ in
                            Color.secondary.opacity(0.1)
                                .aspectRatio(1, contentMode: .fill)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .cornerRadius(6)
                        }
                    }
                } else {
                    // 无插画时的占位
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.05))
                            .aspectRatio(1, contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }
}

#Preview {
    // 示例数据用于预览
    let sampleUser = User(
        profileImageUrls: ProfileImageUrls(medium: "https://via.placeholder.com/150"),
        id: .string("123"),
        name: "示例用户",
        account: "sample_user"
    )
    let sampleIllust = Illusts(
        id: 1,
        title: "示例作品",
        type: "illust",
        imageUrls: ImageUrls(squareMedium: "https://via.placeholder.com/150", medium: "https://via.placeholder.com/300", large: "https://via.placeholder.com/600"),
        caption: "",
        restrict: 0,
        user: sampleUser,
        tags: [],
        tools: [],
        createDate: "",
        pageCount: 1,
        width: 1000,
        height: 1000,
        sanityLevel: 2,
        xRestrict: 0,
        metaSinglePage: MetaSinglePage(originalImageUrl: ""),
        metaPages: [],
        totalView: 100,
        totalBookmarks: 50,
        isBookmarked: false,
        bookmarkRestrict: nil,
        visible: true,
        isMuted: false,
        illustAIType: 1
    )
    let sampleUserPreview = UserPreviews(
        user: sampleUser,
        illusts: [sampleIllust, sampleIllust, sampleIllust],
        novels: [],
        isMuted: false
    )

    UserPreviewCard(userPreview: sampleUserPreview)
}

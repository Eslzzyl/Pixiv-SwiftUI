import SwiftUI

struct UserPreviewCard: View {
    let userPreview: UserPreviews
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 用户信息行
            HStack {
                CachedAsyncImage(
                    urlString: userPreview.user.profileImageUrls?.medium,
                    placeholder: AnyView(Color.gray),
                    expiration: DefaultCacheExpiration.userAvatar
                )
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(userPreview.user.name)
                        .font(.headline)
                    Text(userPreview.user.account)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // 作品预览行
            if !userPreview.illusts.isEmpty {
                HStack(spacing: 4) {
                    ForEach(0..<min(3, userPreview.illusts.count), id: \.self) { index in
                        CachedAsyncImage(urlString: userPreview.illusts[index].imageUrls.squareMedium)
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
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
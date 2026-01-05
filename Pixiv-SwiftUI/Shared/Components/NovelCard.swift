import SwiftUI

struct NovelCard: View {
    let novel: Novel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(
                urlString: novel.imageUrls.medium,
                expiration: DefaultCacheExpiration.novel
            )
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(novel.title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
                .multilineTextAlignment(.leading)
            
            Text(novel.user.name)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)
            
            HStack(spacing: 2) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 10))
                Text(formatTextLength(novel.textLength))
                    .font(.caption2)
                
                Spacer()
                
                Image(systemName: "heart")
                    .font(.system(size: 10))
                Text("\(novel.totalBookmarks)")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            .frame(width: 100)
        }
        .frame(width: 120)
    }
    
    private func formatTextLength(_ length: Int) -> String {
        if length >= 10000 {
            return String(format: "%.1f万字", Double(length) / 10000)
        } else if length >= 1000 {
            return String(format: "%.1f千字", Double(length) / 1000)
        }
        return "\(length)字"
    }
}

#Preview {
    let novel = Novel(
        id: 123,
        title: "示例小说标题",
        caption: "",
        restrict: 0,
        xRestrict: 0,
        isOriginal: true,
        imageUrls: ImageUrls(
            squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg",
            medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
            large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
        ),
        createDate: "2023-12-15T00:00:00+09:00",
        tags: [
            NovelTag(name: "原创", translatedName: nil, addedByUploadedUser: true),
            NovelTag(name: "ファンタジー", translatedName: "奇幻", addedByUploadedUser: true)
        ],
        pageCount: 1,
        textLength: 15000,
        user: User(
            profileImageUrls: ProfileImageUrls(
                px50x50: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
            ),
            id: StringIntValue.string("1"),
            name: "示例作者",
            account: "test_user"
        ),
        series: nil,
        isBookmarked: false,
        totalBookmarks: 1234,
        totalView: 56789,
        visible: true,
        isMuted: false,
        isMypixivOnly: false,
        isXRestricted: false,
        novelAIType: 0
    )
    
    NovelCard(novel: novel)
        .frame(width: 120)
        .padding()
}

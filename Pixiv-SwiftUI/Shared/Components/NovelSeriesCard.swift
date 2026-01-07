import SwiftUI

struct NovelSeriesCard: View {
    let novel: Novel
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(
                urlString: novel.imageUrls.medium,
                expiration: DefaultCacheExpiration.novel
            )
            .frame(width: 80, height: 80)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("#\(index + 1) \(novel.title)")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(novel.user.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.alignleft")
                            .font(.caption2)
                        Text(formatTextLength(novel.textLength))
                            .font(.caption)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                        Text(NumberFormatter.formatCount(novel.totalBookmarks))
                            .font(.caption)
                    }
                    
                    Spacer()
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
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
    VStack(spacing: 8) {
        NovelSeriesCard(
            novel: Novel(
                id: 123,
                title: "测试小说标题",
                caption: "测试简介",
                restrict: 0,
                xRestrict: 0,
                isOriginal: true,
                imageUrls: ImageUrls(
                    squareMedium: "",
                    medium: "",
                    large: ""
                ),
                createDate: "2023-12-15T00:00:00+09:00",
                tags: [],
                pageCount: 1,
                textLength: 15000,
                user: User(
                    profileImageUrls: ProfileImageUrls(px50x50: ""),
                    id: StringIntValue.string("1"),
                    name: "测试作者",
                    account: "test"
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
            ),
            index: 1
        )
        
        NovelSeriesCard(
            novel: Novel(
                id: 124,
                title: "测试小说标题比较长比较长比较长比较长比较长比较长",
                caption: "测试简介",
                restrict: 0,
                xRestrict: 0,
                isOriginal: true,
                imageUrls: ImageUrls(
                    squareMedium: "",
                    medium: "",
                    large: ""
                ),
                createDate: "2023-12-15T00:00:00+09:00",
                tags: [],
                pageCount: 1,
                textLength: 15000,
                user: User(
                    profileImageUrls: ProfileImageUrls(px50x50: ""),
                    id: StringIntValue.string("1"),
                    name: "测试作者",
                    account: "test"
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
            ),
            index: 2
        )
    }
    .padding()
}

import SwiftUI

/// 插画卡片组件
struct IllustCard: View {
    let illust: Illusts

    var body: some View {
        VStack(spacing: 0) {
            // 插画图片
            AsyncImage(url: getImageURL()) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .clipped()
                case .failure, .empty:
                    ZStack {
                        Color.gray.opacity(0.2)
                        ProgressView()
                    }
                @unknown default:
                    Color.gray.opacity(0.2)
                }
            }
            .aspectRatio(3 / 4, contentMode: .fit)

            // 底部信息
            VStack(alignment: .leading, spacing: 4) {
                // 标题
                Text(illust.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                // 作者
                HStack(spacing: 6) {
                    if let urlString = illust.user.profileImageUrls?.px50x50 ?? illust.user.profileImageUrls?.medium,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                            case .failure, .empty:
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 24, height: 24)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }

                    Text(illust.user.name)
                        .font(.caption2)
                        .lineLimit(1)
                }

                // 统计信息
                HStack(spacing: 12) {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                        Text("\(illust.totalBookmarks)")
                            .font(.caption2)
                    }
                    .foregroundColor(.red)

                    HStack(spacing: 2) {
                        Image(systemName: "eye.fill")
                            .font(.caption2)
                        Text("\(illust.totalView)")
                            .font(.caption2)
                    }
                    .foregroundColor(.gray)
                }
            }
            .padding(8)
        }
        .background(Color(white: 0.97))
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    /// 获取插画图片 URL
    private func getImageURL() -> URL? {
        URL(string: illust.imageUrls.medium)
    }
}

#Preview {
    let illust = Illusts(
        id: 123,
        title: "示例插画",
        type: "illust",
        imageUrls: ImageUrls(
            squareMedium:
                "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p0_square1200.jpg",
            medium:
                "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
            large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
        ),
        caption: "示例作品",
        restrict: 0,
        user: User(
            profileImageUrls: ProfileImageUrls(
                px16x16: "",
                px50x50: "",
                px170x170: ""
            ),
            id: StringIntValue.string("1"),
            name: "示例用户",
            account: "test"
        ),
        tags: [],
        tools: [],
        createDate: "2023-12-15T00:00:00+09:00",
        pageCount: 1,
        width: 900,
        height: 1200,
        sanityLevel: 2,
        xRestrict: 0,
        metaSinglePage: nil,
        metaPages: [],
        totalView: 1000,
        totalBookmarks: 500,
        isBookmarked: false,
        visible: true,
        isMuted: false,
        illustAIType: 0
    )

    IllustCard(illust: illust)
        .padding()
}

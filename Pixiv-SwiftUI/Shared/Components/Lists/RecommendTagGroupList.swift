import SwiftUI

struct RecommendTagGroupList: View {
    let tagGroups: [RecommendByTagGroup]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "为你推荐的标签"))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)

            if isLoading && tagGroups.isEmpty {
                SkeletonRecommendTagGroupList()
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            } else if !tagGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(tagGroups, id: \.tag) { group in
                            NavigationLink(value: PixivNavigationRoute.recommendByTag(RecommendByTagTarget(tag: group.tag, translatedName: group.translatedName, illustIds: group.illusts.map { $0.id }))) {
                                RecommendTagGroupCard(group: group)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            }
        }
    }
}

struct RecommendTagGroupCard: View {
    let group: RecommendByTagGroup

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 背景拼图
            HStack(spacing: 2) {
                if let first = group.illusts.first {
                    CachedAsyncImage(
                        urlString: first.imageUrls.medium,
                        contentMode: .fill,
                        expiration: DefaultCacheExpiration.recommend
                    )
                    .frame(width: 140, height: 160)
                    .clipped()
                }

                VStack(spacing: 2) {
                    if group.illusts.count > 1 {
                        CachedAsyncImage(
                            urlString: group.illusts[1].imageUrls.medium,
                            contentMode: .fill,
                            expiration: DefaultCacheExpiration.recommend
                        )
                        .frame(width: 100, height: 79)
                        .clipped()
                    } else {
                        Color.gray.opacity(0.1)
                            .frame(width: 100, height: 79)
                    }

                    if group.illusts.count > 2 {
                        CachedAsyncImage(
                            urlString: group.illusts[2].imageUrls.medium,
                            contentMode: .fill,
                            expiration: DefaultCacheExpiration.recommend
                        )
                        .frame(width: 100, height: 79)
                        .clipped()
                    } else {
                        Color.gray.opacity(0.1)
                            .frame(width: 100, height: 79)
                    }
                }
            }
            .frame(width: 242, height: 160)
            .background(Color.gray.opacity(0.1))
            // 注意：因为是针对iOS17+ / macOS14+开发，可以使用 clipShape(.rect(cornerRadius:)) 等现代API 
            // 为兼容性，使用 clipShape 和 RoundedRectangle
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // 底部蒙版和文字
            LinearGradient(
                gradient: Gradient(colors: [.black.opacity(0.6), .black.opacity(0.0)]),
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 60)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 0))

            VStack(alignment: .leading, spacing: 2) {
                Text(group.tag)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let translated = TagTranslationService.shared.getDisplayTranslation(for: group.tag, officialTranslation: group.translatedName), !translated.isEmpty {
                    Text(translated)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(10)
        }
        .frame(width: 242, height: 160)
        .contentShape(Rectangle())
    }
}

struct SkeletonRecommendTagGroupList: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonRecommendTagGroupCard()
                }
            }
            .padding(.horizontal)
        }
        .disabled(true)
    }
}

struct SkeletonRecommendTagGroupCard: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(spacing: 2) {
                Color.gray.opacity(0.2)
                    .frame(width: 140, height: 160)
                    .skeleton()

                VStack(spacing: 2) {
                    Color.gray.opacity(0.2)
                        .frame(width: 100, height: 79)
                        .skeleton()
                    Color.gray.opacity(0.2)
                        .frame(width: 100, height: 79)
                        .skeleton()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Color.gray.opacity(0.3)
                    .frame(width: 80, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .skeleton()

                Color.gray.opacity(0.3)
                    .frame(width: 60, height: 10)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .skeleton()
            }
            .padding(10)
        }
        .frame(width: 242, height: 160)
    }
}

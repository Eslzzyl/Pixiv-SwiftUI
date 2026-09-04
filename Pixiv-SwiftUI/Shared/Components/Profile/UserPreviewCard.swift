import SwiftUI
import os.log

struct UserPreviewCard: View {
    let userPreview: UserPreviews
    let accentColor: Color

    @State private var isFollowed: Bool?
    @State private var isFollowLoading = false

    init(userPreview: UserPreviews, accentColor: Color = .accentColor) {
        self.userPreview = userPreview
        self.accentColor = accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 用户信息行
            HStack(spacing: 12) {
                AnimatedAvatarImage(
                    urlString: userPreview.user.profileImageUrls?.medium,
                    size: 44,
                    expiration: DefaultCacheExpiration.userAvatar
                )

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

                if let isFollowed {
                    ZStack {
                        // 正常状态：心形按钮
                        Button {
                            toggleFollow()
                        } label: {
                            Image(systemName: isFollowed ? "heart.fill" : "heart")
                                .font(.system(size: 16))
                                .foregroundColor(isFollowed ? accentColor : .secondary)
                                .frame(width: 32, height: 32)
                        }
                        .adaptiveCircularGlassButtonStyle()
                        .opacity(isFollowLoading ? 0 : 1)
                        .sensoryFeedback(.impact(weight: .light), trigger: isFollowed)
                        .accessibilityLabel(isFollowed ? String(localized: "取消关注") : String(localized: "关注"))

                        // 加载状态：ProgressView 覆盖，同时拦截 NavigationLink 点击
                        if isFollowLoading {
                            ProgressView()
                                #if os(macOS)
                                .controlSize(.small)
                                #endif
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                }
            }
            .padding(.horizontal, 4)

            // 作品预览行
            HStack(spacing: 6) {
                if !userPreview.illusts.isEmpty {
                    ForEach(Array(userPreview.illusts.prefix(3).enumerated()), id: \.element.id) { _, illust in
                        CachedAsyncImage(urlString: illust.imageUrls.squareMedium)
                            .aspectRatio(1, contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .clipped()
                            .cornerRadius(8)
                            .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    }

                    // 补充空白槽位，保持布局整齐
                    if userPreview.illusts.count < 3 {
                        ForEach(0..<(3 - userPreview.illusts.count), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.05))
                                .aspectRatio(1, contentMode: .fill)
                        }
                    }
                } else {
                    // 无插画时的占位
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.03))
                            .aspectRatio(1, contentMode: .fill)
                    }
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                )
        }
        .onAppear {
            if isFollowed == nil {
                isFollowed = userPreview.user.isFollowed
            }
        }
    }

    private func toggleFollow() {
        guard let isFollowed, !isFollowLoading else { return }

        let previousState = isFollowed
        let newState = !isFollowed
        let requestGeneration = AccountStore.shared.accountGeneration
        let requestUserId = AccountStore.shared.currentUserId
        self.isFollowed = newState
        isFollowLoading = true

        Task {
            defer { isFollowLoading = false }

            do {
                if newState {
                    let isPrivate = UserSettingStore.shared.userSetting.defaultPrivateLike
                    try await PixivAPI.shared.userAPI.followUser(
                        userId: userPreview.user.id.stringValue,
                        restrict: isPrivate ? "private" : "public"
                    )
                } else {
                    try await PixivAPI.shared.userAPI.unfollowUser(userId: userPreview.user.id.stringValue)
                }
            } catch {
                // 乐观更新失败，回滚到之前的状态
                await MainActor.run {
                    guard AccountStore.shared.isCurrentAccount(generation: requestGeneration, userId: requestUserId) else {
                        return
                    }
                    self.isFollowed = previousState
                }
                Logger.user.error("Failed to toggle follow: \(error)")
            }
        }
    }
}

#Preview {
    // 示例数据用于预览
    let sampleUser = UserDTO(
        profileImageUrls: ProfileImageUrlsDTO(medium: "https://via.placeholder.com/150"),
        id: .string("123"),
        name: "示例用户",
        account: "sample_user",
        mailAddress: nil,
        isPremium: nil,
        xRestrict: nil,
        isMailAuthorized: nil,
        requirePolicyAgreement: nil,
        isAcceptRequest: nil,
        isFollowed: nil
    )
    let sampleIllust = Illusts(
        id: 1,
        title: "示例作品",
        type: "illust",
        imageUrls: ImageUrls(squareMedium: "https://via.placeholder.com/150", medium: "https://via.placeholder.com/300", large: "https://via.placeholder.com/600"),
        caption: "",
        restrict: 0,
        user: sampleUser.toDomain(),
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
        illusts: [IllustDTO.fromDomain(sampleIllust), IllustDTO.fromDomain(sampleIllust), IllustDTO.fromDomain(sampleIllust)],
        novels: [],
        isMuted: false
    )

    UserPreviewCard(userPreview: sampleUserPreview)
}

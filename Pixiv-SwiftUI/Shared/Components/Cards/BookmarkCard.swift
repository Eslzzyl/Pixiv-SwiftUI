import SwiftUI

/// 收藏卡片组件（支持显示已删除标记和缓存状态）
struct BookmarkCard: View {
    @Environment(UserSettingStore.self) var userSettingStore
    #if os(macOS)
    @Environment(\.openWindow) var openWindow
    #endif
    let illust: Illusts
    let columnCount: Int
    var columnWidth: CGFloat?
    var expiration: CacheExpiration?
    var isDeleted: Bool = false
    var cacheStatus: BookmarkCacheStatus = .none

    @State private var isBookmarked: Bool = false

    init(
        illust: Illusts,
        columnCount: Int = 2,
        columnWidth: CGFloat? = nil,
        expiration: CacheExpiration? = nil,
        isDeleted: Bool = false,
        cacheStatus: BookmarkCacheStatus = .none
    ) {
        self.illust = illust
        self.columnCount = columnCount
        self.columnWidth = columnWidth
        self.expiration = expiration
        self.isDeleted = isDeleted
        self.cacheStatus = cacheStatus
        _isBookmarked = State(initialValue: illust.isBookmarked)
    }

    private var isR18: Bool {
        return illust.xRestrict >= 1
    }

    private var shouldBlur: Bool {
        return isR18 && userSettingStore.userSetting.r18DisplayMode == 1
    }

    private var bookmarkIconName: String {
        if !isBookmarked {
            return "heart"
        }
        return illust.bookmarkRestrict == "private" ? "heart.slash.fill" : "heart.fill"
    }

    private var isAI: Bool {
        return illust.illustAIType == 2
    }

    private var isUgoira: Bool {
        return illust.type == "ugoira"
    }

    private var isManga: Bool {
        return illust.type == "manga"
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(
                    urlString: ImageURLHelper.getImageURL(from: illust, quality: userSettingStore.userSetting.feedPreviewQuality),
                    aspectRatio: illust.safeAspectRatio,
                    idealWidth: columnWidth,
                    expiration: expiration
                )
                .clipped()
                .blur(radius: shouldBlur ? 20 : 0)

                VStack {
                    HStack(spacing: 4) {
                        if isDeleted {
                            Text("已删除")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.red)
                                .cornerRadius(8)
                        }

                        if isManga {
                            tagLabel("漫画")
                        }

                        if isUgoira {
                            tagLabel("动图")
                        }

                        if isAI {
                            tagLabel("AI")
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    Spacer()

                    if cacheStatus != .none && userSettingStore.userSetting.bookmarkCacheEnabled {
                        HStack {
                            cacheStatusLabel
                            Spacer()
                        }
                        .padding(6)
                    }
                }

                if illust.pageCount > 1 {
                    Text("\(illust.pageCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(illust.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)

                HStack {
                    Text(illust.user.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if !isDeleted {
                        Button(action: toggleBookmark) {
                            Image(systemName: bookmarkIconName)
                                .foregroundColor(isBookmarked ? .red : .secondary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.impact(weight: .light), trigger: isBookmarked)
                    }
                }
            }
            .padding(8)
        }
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        #endif
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDeleted ? Color.red : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
        #if os(macOS)
        .contextMenu {
            if !isDeleted {
                Button {
                    openWindow(id: "illust-detail", value: illust.id)
                } label: {
                    Label("在新窗口中打开", systemImage: "alternate.window.badge.plus")
                }
            }
        }
        #endif
    }

    @ViewBuilder
    private func tagLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
    }

    @ViewBuilder
    private var cacheStatusLabel: some View {
        switch cacheStatus {
        case .none:
            EmptyView()
        case .notCached:
            Text("未缓存")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
        case .cached(let quality):
            Text(quality.displayName)
                .font(.caption2)
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
        }
    }

    private func toggleBookmark() {
        let wasBookmarked = isBookmarked
        let illustId = illust.id

        isBookmarked.toggle()
        if wasBookmarked {
            illust.totalBookmarks -= 1
            illust.bookmarkRestrict = nil
        } else {
            illust.totalBookmarks += 1
            illust.bookmarkRestrict = "public"
        }

        Task {
            do {
                if wasBookmarked {
                    try await PixivAPI.shared.deleteBookmark(illustId: illustId)
                    if UserSettingStore.shared.userSetting.bookmarkCacheEnabled {
                        BookmarkCacheStore.shared.removeCache(
                            illustId: illustId,
                            ownerId: AccountStore.shared.currentUserId
                        )
                    }
                } else {
                    try await PixivAPI.shared.addBookmark(illustId: illustId, isPrivate: false)
                    if UserSettingStore.shared.userSetting.bookmarkCacheEnabled {
                        BookmarkCacheStore.shared.addOrUpdateCache(
                            illust: illust,
                            ownerId: AccountStore.shared.currentUserId,
                            bookmarkRestrict: "public"
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isBookmarked = wasBookmarked
                    if wasBookmarked {
                        illust.totalBookmarks += 1
                        illust.bookmarkRestrict = "public"
                    } else {
                        illust.totalBookmarks -= 1
                        illust.bookmarkRestrict = nil
                    }
                }
            }
        }
    }
}

/// 缓存状态枚举
enum BookmarkCacheStatus: Equatable {
    case none
    case notCached
    case cached(BookmarkCacheQuality)
}

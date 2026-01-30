import SwiftUI
import TranslationKit

#if os(macOS)
import AppKit
#endif

struct NovelDetailView: View {
    let novel: Novel
    @State private var novelData: Novel
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(AccountStore.self) var accountStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var isBookmarked: Bool
    @State private var isFollowed: Bool?
    @State private var totalComments: Int?
    @State private var showCopyToast = false
    @State private var showBlockTagToast = false
    @State private var showNotLoggedInToast = false
    @State private var navigateToUserId: String?
    @State private var navigateToIllustId: Int?
    @State private var navigateToNovelId: Int?
    @State private var navigateToReaderId: Int?
    @State private var showAuthView = false

    #if os(iOS)
    @State private var showComments = false
    #endif
    #if os(macOS)
    @State private var coverAspectRatio: CGFloat = 0
    @State private var leftColumnWidth: CGFloat? = nil
    #endif

    @Environment(\.dismiss) private var dismiss

    init(novel: Novel) {
        self.novel = novel
        self._novelData = State(initialValue: novel)
        self._isBookmarked = State(initialValue: novel.isBookmarked)
        self._isFollowed = State(initialValue: novel.user.isFollowed)
        self._totalComments = State(initialValue: novel.totalComments)
    }

    private var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    var body: some View {
        GeometryReader { proxy in
            #if os(macOS)
            let totalWidth = proxy.size.width
            let minLeftWidth: CGFloat = 350
            let minRightWidth: CGFloat = 400
            let defaultLeftWidth = totalWidth * 0.6
            
            let rawLeftWidth = leftColumnWidth ?? defaultLeftWidth
            let currentLeftWidth = max(minLeftWidth, min(rawLeftWidth, totalWidth - minRightWidth))

            HStack(spacing: 0) {
                // Left Column: Cover and Tags (Main Content)
                ScrollView {
                    VStack(spacing: 0) {
                        NovelDetailCoverSection(
                            novel: novelData,
                            coverAspectRatio: coverAspectRatio > 0 ? coverAspectRatio : nil,
                            onCoverSizeChange: { size in
                                guard size.width > 0, size.height > 0 else { return }
                                let newRatio = size.width / size.height
                                if abs(coverAspectRatio - newRatio) > 0.01 {
                                    coverAspectRatio = newRatio
                                }
                            },
                            onStartReading: {
                                navigateToReaderId = novelData.id
                            }
                        )
                            .frame(maxWidth: .infinity)

                        Divider()
                            .padding(.vertical, 8)

                        tagsSection
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                    }
                    .padding(.trailing, 16)
                }
                .frame(width: currentLeftWidth)

                // Draggable Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1)
                    .overlay(
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 8)
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                if hovering {
                                    #if os(macOS)
                                    NSCursor.resizeLeftRight.push()
                                    #endif
                                } else {
                                    #if os(macOS)
                                    NSCursor.pop()
                                    #endif
                                }
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newWidth = currentLeftWidth + value.translation.width
                                if newWidth > minLeftWidth && newWidth < totalWidth - minRightWidth {
                                    leftColumnWidth = newWidth
                                }
                            }
                    )

                // Right Column: Info and Comments
                ScrollView {
                    VStack(spacing: 0) {
                        NovelDetailInfoSection(
                            novel: novelData,
                            userSettingStore: userSettingStore,
                            accountStore: accountStore,
                            colorScheme: colorScheme,
                            isBookmarked: $isBookmarked,
                            isFollowed: $isFollowed,
                            totalComments: $totalComments,
                            showNotLoggedInToast: $showNotLoggedInToast,
                            navigateToUserId: $navigateToUserId
                        )
                        .padding()

                        Divider()
                            .padding(.horizontal)

                        NovelCommentsPanelInlineView(
                            novel: novelData,
                            onUserTapped: { userId in
                                navigateToUserId = userId
                            },
                            hasInternalScroll: false
                        )
                        .padding()

                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #else
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NovelDetailCoverSection(
                        novel: novelData,
                        onStartReading: {
                            navigateToReaderId = novelData.id
                        }
                    )
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .padding(.horizontal)

                    NovelDetailInfoSection(
                        novel: novelData,
                        userSettingStore: userSettingStore,
                        accountStore: accountStore,
                        colorScheme: colorScheme,
                        isBookmarked: $isBookmarked,
                        isFollowed: $isFollowed,
                        totalComments: $totalComments,
                        showNotLoggedInToast: $showNotLoggedInToast,
                        navigateToUserId: $navigateToUserId
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #if os(iOS)
        .toolbarBackground(.hidden, for: .navigationBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { copyToClipboard(String(novel.id)) }) {
                        Label(String(localized: "复制 ID"), systemImage: "doc.on.doc")
                    }

                    Button(action: shareNovel) {
                        Label(String(localized: "分享"), systemImage: "square.and.arrow.up")
                    }

                    if isLoggedIn {
                        Divider()

                        Button(action: {
                            if isBookmarked {
                                toggleBookmark(forceUnbookmark: true)
                            } else {
                                toggleBookmark(isPrivate: false)
                            }
                        }) {
                            Label(
                                isBookmarked ? String(localized: "取消收藏") : String(localized: "收藏"),
                                systemImage: isBookmarked ? "heart.fill" : "heart"
                            )
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .toast(isPresented: $showCopyToast, message: String(localized: "已复制"))
        .toast(isPresented: $showBlockTagToast, message: String(localized: "已屏蔽 Tag"))
        .toast(isPresented: $showNotLoggedInToast, message: String(localized: "请先登录"), duration: 2.0)
        #if os(iOS)
        .sheet(isPresented: $showComments) {
            NovelCommentsPanelView(novel: novelData, isPresented: $showComments)
        }
        #endif
        .onAppear {
            fetchUserDetailIfNeeded()
            fetchTotalCommentsIfNeeded()
            recordGlance()
        }
        .navigationDestination(item: $navigateToUserId) { userId in
            UserDetailView(userId: userId)
        }
        .navigationDestination(item: $navigateToIllustId) { illustId in
            IllustLoaderView(illustId: illustId)
        }
        .navigationDestination(item: $navigateToNovelId) { novelId in
            NovelLoaderView(novelId: novelId)
        }
        .navigationDestination(item: $navigateToReaderId) { novelId in
            NovelReaderView(novelId: novelId)
        }
        .environment(\.openURL, OpenURLAction { url in
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if url.scheme == "pixiv" {
                     let pathId = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                     if components.host == "illusts", let id = Int(pathId) {
                         navigateToIllustId = id
                         return .handled
                     } else if components.host == "users" {
                         navigateToUserId = pathId
                         return .handled
                     } else if components.host == "novel", let id = Int(pathId) {
                         navigateToNovelId = id
                         return .handled
                     }
                } else if url.host?.contains("pixiv.net") == true {
                     let pathComponents = components.path.split(separator: "/")
                     if pathComponents.count >= 2 {
                         if pathComponents[0] == "artworks", let id = Int(pathComponents[1]) {
                             navigateToIllustId = id
                             return .handled
                         } else if pathComponents[0] == "users" {
                             navigateToUserId = String(pathComponents[1])
                             return .handled
                         }
                     }
                     if components.path.contains("novel/show.php"),
                        let idStr = components.queryItems?.first(where: { $0.name == "id" })?.value,
                        let id = Int(idStr) {
                         navigateToNovelId = id
                         return .handled
                     }
                }
            }
            return .systemAction
        })
        .sheet(isPresented: $showAuthView) {
            AuthView(accountStore: accountStore)
        }
    }

    private func toggleBookmark(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
        guard isLoggedIn else {
            showNotLoggedInToast = true
            return
        }

        let wasBookmarked = isBookmarked
        let novelId = novel.id

        if forceUnbookmark && wasBookmarked {
            isBookmarked = false
            novelData.isBookmarked = false
            novelData.totalBookmarks -= 1
        } else if wasBookmarked {
            novelData.isBookmarked = true
        } else {
            isBookmarked = true
            novelData.isBookmarked = true
            novelData.totalBookmarks += 1
        }

        Task {
            do {
                if forceUnbookmark && wasBookmarked {
                    try await PixivAPI.shared.novelAPI?.unbookmarkNovel(novelId: novelId)
                } else if wasBookmarked {
                    try await PixivAPI.shared.novelAPI?.unbookmarkNovel(novelId: novelId)
                    try await PixivAPI.shared.novelAPI?.bookmarkNovel(novelId: novelId, restrict: isPrivate ? "private" : "public")
                } else {
                    try await PixivAPI.shared.novelAPI?.bookmarkNovel(novelId: novelId, restrict: isPrivate ? "private" : "public")
                }
            } catch {
                await MainActor.run {
                    if forceUnbookmark && wasBookmarked {
                        isBookmarked = true
                        novelData.isBookmarked = true
                        novelData.totalBookmarks += 1
                    } else if wasBookmarked {
                        isBookmarked = true
                        novelData.isBookmarked = true
                    } else {
                        isBookmarked = false
                        novelData.isBookmarked = false
                        novelData.totalBookmarks -= 1
                    }
                }
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #else
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(text, forType: .string)
        #endif
        showCopyToast = true
    }

    private func shareNovel() {
        guard let url = URL(string: "https://www.pixiv.net/novel/show.php?id=\(novel.id)") else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }

    private func fetchUserDetailIfNeeded() {
        guard isFollowed == nil else { return }

        Task {
            do {
                let detail = try await PixivAPI.shared.getUserDetail(userId: novel.user.id.stringValue)
                await MainActor.run {
                    self.isFollowed = detail.user.isFollowed
                }
            } catch {
                print("Failed to fetch user detail: \(error)")
            }
        }
    }

    private func fetchTotalCommentsIfNeeded() {
        Task {
            do {
                let comments = try await PixivAPI.shared.getNovelComments(novelId: novel.id)
                await MainActor.run {
                    self.totalComments = comments.comments.count
                }
            } catch {
                print("Failed to fetch comments: \(error)")
            }
        }
    }

    private func recordGlance() {
        let store = NovelStore()
        try? store.recordGlance(novel.id, novel: novelData)
    }

    @ViewBuilder
    private var tagsSection: some View {
        if !novel.tags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "标签"))
                    .font(.headline)
                    .foregroundColor(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(novel.tags, id: \.name) { tag in
                        Group {
                            if isLoggedIn {
                                NavigationLink(value: SearchResultTarget(word: tag.name)) {
                                    TagChip(tag: tag)
                                }
                            } else {
                                TagChip(tag: tag)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(action: { copyToClipboard(tag.name) }) {
                                Label(String(localized: "复制 tag"), systemImage: "doc.on.doc")
                            }

                            if isLoggedIn {
                                Button(action: {
                                    try? userSettingStore.addBlockedTagWithInfo(tag.name, translatedName: tag.translatedName)
                                    showBlockTagToast = true
                                    dismiss()
                                }) {
                                    Label(String(localized: "屏蔽 tag"), systemImage: "eye.slash")
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NovelDetailView(novel: Novel(
            id: 123,
            title: "示例小说标题",
            caption: "这是一段小说简介，可以包含 HTML 标签。",
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
                NovelTag(name: "ファンタジー", translatedName: "奇幻", addedByUploadedUser: true),
                NovelTag(name: "長編", translatedName: "长篇", addedByUploadedUser: false)
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
        ))
    }
}

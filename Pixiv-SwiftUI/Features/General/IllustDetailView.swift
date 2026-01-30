import SwiftUI
import Kingfisher
import TranslationKit
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct IllustDetailView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(AccountStore.self) var accountStore
    @Environment(\.colorScheme) private var colorScheme
    let illust: Illusts
    @State private var illustStore = IllustStore()
    @State private var currentPage = 0
    @State private var isCommentsPanelPresented = false
    @State private var isFullscreen = false
    @State private var showCopyToast = false
    @State private var showBlockTagToast = false
    @State private var showBlockIllustToast = false
    @State private var isFollowLoading = false
    @State private var relatedIllusts: [Illusts] = []
    @State private var isLoadingRelated = false
    @State private var isFetchingMoreRelated = false
    @State private var relatedNextUrl: String?
    @State private var hasMoreRelated = true
    @State private var relatedIllustError: String?
    @State private var navigateToIllust: Illusts?
    @State private var showRelatedIllustDetail = false
    #if os(macOS)
    @State private var currentImageAspectRatio: CGFloat = 0
    @State private var leftColumnWidth: CGFloat? = nil
    #endif
    @State private var isFollowed: Bool = false
    @State private var isBookmarked: Bool = false
    @State private var isBlockTriggered: Bool = false
    @State private var totalComments: Int?
    @State private var navigateToUserId: String?
    @State private var navigateToIllustId: Int?
    @State private var navigateToNovelId: Int?
    @State private var shouldLoadRelated: Bool = false
    @State private var showSaveToast = false
    @State private var showAuthView = false
    @State private var showNotLoggedInToast = false

    private var screenWidth: CGFloat {
        #if os(iOS)
        return UIScreen.main.bounds.width
        #elseif os(macOS)
        return NSScreen.main?.frame.width ?? 0
        #else
        return 0
        #endif
    }
    @State private var isSaving = false
    @State private var pendingSaveURL: URL?
    @State private var navigateToDownloadTasks = false
    @Namespace private var animation
    @Environment(\.dismiss) private var dismiss

    private let cache = CacheManager.shared
    private let commentsExpiration: CacheExpiration = .minutes(10)

    init(illust: Illusts) {
        self.illust = illust
        _isFollowed = State(initialValue: illust.user.isFollowed ?? false)
        _isBookmarked = State(initialValue: illust.isBookmarked)
        _totalComments = State(initialValue: illust.totalComments)
    }

    private var isMultiPage: Bool {
        illust.pageCount > 1 || !illust.metaPages.isEmpty
    }

    private var isUgoira: Bool {
        illust.type == "ugoira"
    }

    private var isManga: Bool {
        illust.type == "manga"
    }

    private var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    private var zoomImageURLs: [String] {
        let quality = isManga ? userSettingStore.userSetting.mangaQuality : userSettingStore.userSetting.zoomQuality
        if !illust.metaPages.isEmpty {
            return illust.metaPages.indices.compactMap { index in
                ImageURLHelper.getPageImageURL(from: illust, page: index, quality: quality)
            }
        }
        return [ImageURLHelper.getImageURL(from: illust, quality: quality)]
    }

    private var zoomImageAspectRatios: [CGFloat] {
        // 由于 MetaPages 中通常不包含单独的宽高信息（通常所有页宽高一致或需单独获取）
        // 这里暂时使用原图的比例作为所有页的初始比例
        if !illust.metaPages.isEmpty {
            return Array(repeating: illust.safeAspectRatio, count: illust.metaPages.count)
        }
        return [illust.safeAspectRatio]
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                #if os(macOS)
                let totalWidth = proxy.size.width
                let minLeftWidth: CGFloat = 250
                let minRightWidth: CGFloat = 250
                let defaultLeftWidth = totalWidth * 0.65
                
                let rawLeftWidth = leftColumnWidth ?? defaultLeftWidth
                let currentLeftWidth = max(minLeftWidth, min(rawLeftWidth, totalWidth - minRightWidth))

                HStack(spacing: 0) {
                    // Left Column: Image and Related
                    ScrollView {
                        VStack(spacing: 0) {
                            IllustDetailImageSection(
                                illust: illust,
                                userSettingStore: userSettingStore,
                                isFullscreen: $isFullscreen,
                                animation: animation,
                                currentPage: $currentPage,
                                containerWidth: currentLeftWidth,
                                minContainerHeight: proxy.size.height * 0.6,
                                currentAspectRatio: $currentImageAspectRatio,
                                disableAspectRatioAnimation: true
                            )

                            IllustDetailRelatedSection(
                                illustId: illust.id,
                                isLoggedIn: isLoggedIn,
                                relatedIllusts: $relatedIllusts,
                                isLoadingRelated: $isLoadingRelated,
                                isFetchingMoreRelated: $isFetchingMoreRelated,
                                relatedNextUrl: $relatedNextUrl,
                                hasMoreRelated: $hasMoreRelated,
                                relatedIllustError: $relatedIllustError,
                                width: currentLeftWidth
                            )
                            .padding(.trailing, 16)
                        }
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
                            IllustDetailInfoSection(
                                illust: illust,
                                userSettingStore: userSettingStore,
                                accountStore: accountStore,
                                colorScheme: colorScheme,
                                isFollowed: $isFollowed,
                                isBookmarked: $isBookmarked,
                                totalComments: $totalComments,
                                showNotLoggedInToast: $showNotLoggedInToast,
                                showCopyToast: $showCopyToast,
                                showBlockTagToast: $showBlockTagToast,
                                isBlockTriggered: $isBlockTriggered,
                                isCommentsPanelPresented: $isCommentsPanelPresented,
                                navigateToUserId: $navigateToUserId
                            )
                            .padding()

                            Divider()
                                .padding(.horizontal)

                            CommentsPanelInlineView(
                                illust: illust,
                                onUserTapped: { userId in
                                    navigateToUserId = userId
                                },
                                hasInternalScroll: false
                            )
                            .padding()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #else
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        IllustDetailImageSection(
                            illust: illust,
                            userSettingStore: userSettingStore,
                            isFullscreen: $isFullscreen,
                            animation: animation,
                            currentPage: $currentPage
                        )
                        .frame(maxWidth: proxy.size.width)

                        IllustDetailInfoSection(
                            illust: illust,
                            userSettingStore: userSettingStore,
                            accountStore: accountStore,
                            colorScheme: colorScheme,
                            isFollowed: $isFollowed,
                            isBookmarked: $isBookmarked,
                            totalComments: $totalComments,
                            showNotLoggedInToast: $showNotLoggedInToast,
                            showCopyToast: $showCopyToast,
                            showBlockTagToast: $showBlockTagToast,
                            isBlockTriggered: $isBlockTriggered,
                            isCommentsPanelPresented: $isCommentsPanelPresented,
                            navigateToUserId: $navigateToUserId
                        )
                        .padding()
                        .frame(maxWidth: proxy.size.width)

                        IllustDetailRelatedSection(
                            illustId: illust.id,
                            isLoggedIn: isLoggedIn,
                            relatedIllusts: $relatedIllusts,
                            isLoadingRelated: $isLoadingRelated,
                            isFetchingMoreRelated: $isFetchingMoreRelated,
                            relatedNextUrl: $relatedNextUrl,
                            hasMoreRelated: $hasMoreRelated,
                            relatedIllustError: $relatedIllustError,
                            width: proxy.size.width
                        )
                        .padding(.trailing, 16)
                    }
                }
                #endif
            }
            .ignoresSafeArea(edges: .top)
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(iOS)
            .sheet(isPresented: $isCommentsPanelPresented) {
                IllustCommentsPanelView(
                    illust: illust,
                    isPresented: $isCommentsPanelPresented,
                    onUserTapped: { userId in
                        isCommentsPanelPresented = false
                        navigateToUserId = userId
                    }
                )
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { copyToClipboard(String(illust.id)) }) {
                            Label(String(localized: "复制 ID"), systemImage: "doc.on.doc")
                        }

                        Button(action: shareIllust) {
                            Label(String(localized: "分享"), systemImage: "square.and.arrow.up")
                        }

                        if isLoggedIn {
                            Button(action: {
                                if isBookmarked {
                                    bookmarkIllust(forceUnbookmark: true)
                                } else {
                                    bookmarkIllust(isPrivate: false)
                                }
                            }) {
                                Label(
                                    isBookmarked ? String(localized: "取消收藏") : String(localized: "收藏"),
                                    systemImage: isBookmarked ? (illust.bookmarkRestrict == "private" ? "heart.slash.fill" : "heart.fill") : "heart"
                                )
                            }

                            Divider()

                            #if os(iOS)
                            Button(action: {
                                Task {
                                    await saveIllust()
                                }
                            }) {
                                Label(String(localized: "保存到相册"), systemImage: "photo.on.rectangle")
                            }
                            #else
                            Button(action: {
                                Task {
                                    await showSavePanel()
                                }
                            }) {
                                Label(String(localized: "保存…"), systemImage: "square.and.arrow.down")
                            }
                            #endif

                            if userSettingStore.userSetting.illustDetailSaveSkipLongPress {
                                Button(action: {
                                    Task {
                                        await saveIllust()
                                    }
                                }) {
                                    Label(String(localized: "快速保存"), systemImage: "bolt.fill")
                                }
                            }

                            Divider()

                            Button(role: .destructive, action: {
                                isBlockTriggered = true
                                try? userSettingStore.addBlockedIllustWithInfo(
                                    illust.id,
                                    title: illust.title,
                                    authorId: illust.user.id.stringValue,
                                    authorName: illust.user.name,
                                    thumbnailUrl: illust.imageUrls.squareMedium
                                )
                                showBlockIllustToast = true
                                dismiss()
                            }) {
                                Label(String(localized: "屏蔽此作品"), systemImage: "eye.slash")
                            }
                            .sensoryFeedback(.impact(weight: .medium), trigger: isBlockTriggered)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                print("[IllustDetailView] Appeared with illust id=\(illust.id)")
                preloadAllImages()
                fetchTotalCommentsIfNeeded()
                Task {
                    try? illustStore.recordGlance(illust.id, illust: illust)
                }
            }
            #if os(macOS)
            .navigationTitle(illust.title)
            #endif
            #if os(iOS)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
            .toolbar(isFullscreen ? .hidden : .visible, for: .tabBar)
            #endif

            #if os(iOS)
            if isFullscreen {
                FullscreenImageView(
                    imageURLs: zoomImageURLs,
                    aspectRatios: zoomImageAspectRatios,
                    initialPage: $currentPage,
                    isPresented: $isFullscreen,
                    animation: animation
                )
                .zIndex(1)
            }
            #endif
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
                     // Simple handling for common pixiv web links
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
        .toast(isPresented: $showCopyToast, message: String(localized: "已复制"))
        .toast(isPresented: $showBlockTagToast, message: String(localized: "已屏蔽 Tag"))
        .toast(isPresented: $showBlockIllustToast, message: String(localized: "已屏蔽作品"))
        .toast(isPresented: $showSaveToast, message: String(localized: "已添加到下载队列"))
        .navigationDestination(isPresented: $navigateToDownloadTasks) {
            DownloadTasksView()
        }
        .sheet(isPresented: $showAuthView) {
            AuthView(accountStore: accountStore)
        }
        .toast(isPresented: $showNotLoggedInToast, message: String(localized: "请先登录"), duration: 2.0)
    }

    private func preloadAllImages() {
        guard isMultiPage else { return }

        Task {
            await withTaskGroup(of: Void.self) { group in
                let quality = userSettingStore.userSetting.pictureQuality
                let urls: [String]
                if !illust.metaPages.isEmpty {
                    urls = illust.metaPages.indices.compactMap { index in
                        ImageURLHelper.getPageImageURL(from: illust, page: index, quality: quality)
                    }
                } else {
                    urls = [ImageURLHelper.getImageURL(from: illust, quality: quality)]
                }

                for urlString in urls {
                    group.addTask {
                        await self.preloadImage(urlString: urlString)
                    }
                }
            }
        }
    }

    private func preloadImage(urlString: String) async {
        guard let url = URL(string: urlString) else { return }

        let source: Source
        if shouldUseDirectConnection(url: url) {
            source = .directNetwork(url)
        } else {
            source = .network(url)
        }

        let options: KingfisherOptionsInfo = [
            .requestModifier(PixivImageLoader.shared),
            .cacheOriginalImage
        ]

        _ = try? await KingfisherManager.shared.retrieveImage(with: source, options: options)
    }

    private func shouldUseDirectConnection(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return NetworkModeStore.shared.useDirectConnection &&
               (host.contains("i.pximg.net") || host.contains("img-master.pixiv.net"))
    }

    private func shareIllust() {
        guard let url = URL(string: "https://www.pixiv.net/artworks/\(illust.id)") else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }

    private func bookmarkIllust(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
        guard isLoggedIn else {
            showNotLoggedInToast = true
            return
        }

        let wasBookmarked = isBookmarked
        let illustId = illust.id

        if forceUnbookmark && wasBookmarked {
            isBookmarked = false
            illust.isBookmarked = false
            illust.totalBookmarks -= 1
            illust.bookmarkRestrict = nil
        } else if wasBookmarked {
            illust.bookmarkRestrict = isPrivate ? "private" : "public"
        } else {
            isBookmarked = true
            illust.isBookmarked = true
            illust.totalBookmarks += 1
            illust.bookmarkRestrict = isPrivate ? "private" : "public"
        }

        Task {
            do {
                if forceUnbookmark && wasBookmarked {
                    try await PixivAPI.shared.deleteBookmark(illustId: illustId)
                } else if wasBookmarked {
                    try await PixivAPI.shared.deleteBookmark(illustId: illustId)
                    try await PixivAPI.shared.addBookmark(illustId: illustId, isPrivate: isPrivate)
                } else {
                    try await PixivAPI.shared.addBookmark(illustId: illustId, isPrivate: isPrivate)
                }
            } catch {
                await MainActor.run {
                    if forceUnbookmark && wasBookmarked {
                        isBookmarked = true
                        illust.isBookmarked = true
                        illust.totalBookmarks += 1
                        illust.bookmarkRestrict = isPrivate ? "private" : "public"
                    } else if wasBookmarked {
                        illust.bookmarkRestrict = isPrivate ? "public" : "private"
                    } else {
                        isBookmarked = false
                        illust.isBookmarked = false
                        illust.totalBookmarks -= 1
                        illust.bookmarkRestrict = nil
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

    private func saveIllust() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        if isUgoira {
            await saveUgoira()
        } else {
            let quality = userSettingStore.userSetting.downloadQuality
            await DownloadStore.shared.addTask(illust, quality: quality)
        }
        showSaveToast = true
    }

    private func saveUgoira() async {
        print("[IllustDetailView] 开始保存动图: \(illust.id)")
        await DownloadStore.shared.addUgoiraTask(illust)
    }

    #if os(macOS)
    private func showSavePanel() async {
        if !isUgoira && illust.pageCount > 1 {
            // 多图插画：由于沙盒限制，需要选择文件夹而不是具体文件
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.title = "选择保存目录"
            panel.prompt = "保存到此目录"

            let result = await withCheckedContinuation { continuation in
                panel.begin { response in
                    continuation.resume(returning: response)
                }
            }

            guard result == .OK, let url = panel.url else { return }
            await performSave(to: url)
        } else {
            // 单图或动图：使用 NSSavePanel 选择具体文件名
            let panel = NSSavePanel()
            if isUgoira {
                panel.allowedContentTypes = [.gif]
            } else {
                panel.allowedContentTypes = [.png, .jpeg]
            }
            let safeTitle = illust.title.replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
            panel.nameFieldStringValue = "\(illust.user.name)_\(safeTitle)\(isUgoira ? ".gif" : "")"
            panel.title = isUgoira ? "保存动图" : "保存插画"

            let result = await withCheckedContinuation { continuation in
                panel.begin { response in
                    continuation.resume(returning: response)
                }
            }

            guard result == .OK, let url = panel.url else { return }
            await performSave(to: url)
        }
    }

    private func performSave(to url: URL) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        if isUgoira {
            await DownloadStore.shared.addUgoiraTask(illust, customSaveURL: url)
        } else {
            let quality = userSettingStore.userSetting.downloadQuality
            await DownloadStore.shared.addTask(illust, quality: quality, customSaveURL: url)
        }
        showSaveToast = true
    }
    #endif

    private func fetchTotalCommentsIfNeeded() {
        guard totalComments == nil else { return }

        let cacheKey = CacheManager.illustDetailKey(illustId: illust.id)
        if let cached: Illusts = cache.get(forKey: cacheKey), let comments = cached.totalComments, comments > 0 {
            totalComments = comments
            return
        }

        Task {
            do {
                let detail = try await PixivAPI.shared.getIllustDetail(illustId: illust.id)
                await MainActor.run {
                    self.totalComments = detail.totalComments
                }
            } catch {
                print("Failed to fetch totalComments: \(error)")
            }
        }
    }
}

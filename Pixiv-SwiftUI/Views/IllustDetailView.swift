import SwiftUI
import Kingfisher
import TranslationKit

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// 插画详情页
struct IllustDetailView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(\.colorScheme) private var colorScheme
    let illust: Illusts
    @State private var currentPage = 0
    @State private var isCommentsPanelPresented = false
    @State private var isFullscreen = false
    @State private var showCopyToast = false
    @State private var showBlockTagToast = false
    @State private var showBlockIllustToast = false
    @State private var isFollowLoading = false
    @StateObject private var searchStore = SearchStore()
    @State private var selectedTag: String?
    @State private var navigateToSearch = false
    @State private var relatedIllusts: [Illusts] = []
    @State private var isLoadingRelated = false
    @State private var isFetchingMoreRelated = false
    @State private var relatedNextUrl: String?
    @State private var hasMoreRelated = true
    @State private var relatedIllustError: String?
    @State private var navigateToIllust: Illusts?
    @State private var showRelatedIllustDetail = false
    @State private var pageSizes: [Int: CGSize] = [:]
    @State private var currentAspectRatio: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isFollowed: Bool = false
    @State private var isBookmarked: Bool = false
    @State private var isBlockTriggered: Bool = false
    @Namespace private var animation
    @Environment(\.dismiss) private var dismiss

    init(illust: Illusts) {
        self.illust = illust
        _isFollowed = State(initialValue: illust.user.isFollowed ?? false)
        _isBookmarked = State(initialValue: illust.isBookmarked)
    }

    private var isMultiPage: Bool {
        illust.pageCount > 1 || !illust.metaPages.isEmpty
    }

    private var isUgoira: Bool {
        illust.type == "ugoira"
    }

    /// 获取收藏图标，根据收藏状态和类型返回不同的图标
    private var bookmarkIconName: String {
        if !isBookmarked {
            return "heart"
        }
        return illust.bookmarkRestrict == "private" ? "heart.slash.fill" : "heart.fill"
    }

    /// 顶部 scrim 透明度，根据滚动偏移计算
    private var scrimOpacity: CGFloat {
        max(0, 0.1 - abs(scrollOffset) / 20 * 0.1)
    }

    private var imageURLs: [String] {
        let quality = userSettingStore.userSetting.pictureQuality
        if !illust.metaPages.isEmpty {
            return illust.metaPages.enumerated().compactMap { index, _ in
                ImageURLHelper.getPageImageURL(from: illust, page: index, quality: quality)
            }
        }
        return [ImageURLHelper.getImageURL(from: illust, quality: quality)]
    }

    private var zoomImageURLs: [String] {
        let quality = userSettingStore.userSetting.zoomQuality
        if !illust.metaPages.isEmpty {
            return illust.metaPages.enumerated().compactMap { index, _ in
                ImageURLHelper.getPageImageURL(from: illust, page: index, quality: quality)
            }
        }
        return [ImageURLHelper.getImageURL(from: illust, quality: quality)]
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                    }
                    .frame(height: 0)
                    
                    imageSection

                VStack(alignment: .leading, spacing: 16) {
                    // 标题
                    TranslatableText(text: illust.title, font: .title2)
                        .fontWeight(.bold)

                    // 作者
                    authorSection
                        .padding(.vertical, -4) // 调整间距

                    // 操作按钮
                    actionButtons

                    // 紧凑的元数据行：ID、浏览量、收藏数、日期
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "number")
                                .font(.caption2)
                            Text(String(illust.id))
                                .font(.caption)
                                .textSelection(.enabled)
                            
                            Button(action: {
                                copyToClipboard(String(illust.id))
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.caption2)
                            Text(NumberFormatter.formatCount(illust.totalView))
                                .font(.caption)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: bookmarkIconName)
                                .font(.caption2)
                            Text(NumberFormatter.formatCount(illust.totalBookmarks))
                                .font(.caption)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(formatDateTime(illust.createDate))
                                .font(.caption)
                        }
                        
                        Spacer()
                    }
                    .foregroundColor(.secondary)

                    Divider()

                    // 标签
                    tagsSection

                    // 简介
                    if !illust.caption.isEmpty {
                        Divider()
                        captionSection
                    }
                }
                .padding()

                // 相关推荐
                relatedIllustsSection
            }
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
        }
        .ignoresSafeArea(edges: .top)
        #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $isCommentsPanelPresented) {
            CommentsPanelView(illust: illust, isPresented: $isCommentsPanelPresented)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { copyToClipboard(String(illust.id)) }) {
                        Label("复制 ID", systemImage: "doc.on.doc")
                    }

                    Button(action: shareIllust) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }

                    Button(action: {
                        if isBookmarked {
                            bookmarkIllust(forceUnbookmark: true)
                        } else {
                            bookmarkIllust(isPrivate: false)
                        }
                    }) {
                        Label(
                            isBookmarked ? "取消收藏" : "收藏",
                            systemImage: bookmarkIconName
                        )
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
                        Label("屏蔽此作品", systemImage: "eye.slash")
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: isBlockTriggered)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            preloadAllImages()
            fetchRelatedIllusts()
        }
        #if os(iOS)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
        .toolbar(isFullscreen ? .hidden : .visible, for: .tabBar)
        #endif
        
        if isFullscreen {
            FullscreenImageView(
                imageURLs: zoomImageURLs,
                initialPage: $currentPage,
                isPresented: $isFullscreen,
                animation: animation
            )
            .zIndex(1)
        }
    }
    .navigationDestination(isPresented: $navigateToSearch) {
        if let tag = selectedTag {
            SearchResultView(word: tag, store: searchStore)
        }
    }
    .toast(isPresented: $showCopyToast, message: "已复制到剪贴板")
    .toast(isPresented: $showBlockTagToast, message: "已屏蔽 Tag")
    .toast(isPresented: $showBlockIllustToast, message: "已屏蔽作品")
    }
    
    private func preloadAllImages() {
        guard isMultiPage else { return }
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                for urlString in imageURLs {
                    group.addTask {
                        await self.preloadImage(urlString: urlString)
                    }
                }
            }
        }
    }
    
    private func preloadImage(urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        
        let options: KingfisherOptionsInfo = [
            .requestModifier(PixivImageLoader.shared),
            .cacheOriginalImage
        ]
        
        _ = try? await KingfisherManager.shared.retrieveImage(with: url, options: options)
    }
    
    private var imageSection: some View {
        ZStack(alignment: .bottomTrailing) {
            if isMultiPage {
                multiPageImageSection
            } else {
                singlePageImageSection
            }
        }
        .overlay(alignment: .top) {
            LinearGradient(gradient: Gradient(colors: [Color.white.opacity(scrimOpacity), .clear]), startPoint: .top, endPoint: .bottom)
                .frame(height: 100)
                .allowsHitTesting(false)
        }
    }

    private var singlePageImageSection: some View {
        Group {
            if isUgoira {
                UgoiraLoader(illust: illust)
            } else {
                standardImageSection
                    .onTapGesture {
                        isFullscreen = true
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(CGFloat(illust.width) / CGFloat(illust.height), contentMode: .fit)
    }

    private var standardImageSection: some View {
        CachedAsyncImage(
            urlString: ImageURLHelper.getImageURL(from: illust, quality: 2),
            expiration: DefaultCacheExpiration.illustDetail
        )
    }
    
    private var multiPageImageSection: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                pageImage(url: url, index: index)
                    .tag(index)
            }
        }
        #if canImport(UIKit)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
        .frame(maxWidth: .infinity)
        .aspectRatio(aspectRatioForPage(currentPage), contentMode: .fit)
        .onAppear {
            currentAspectRatio = CGFloat(illust.width) / CGFloat(illust.height)
        }
        .onChange(of: currentPage) { _, newPage in
            updateAspectRatio(for: newPage)
        }
        .onTapGesture {
            isFullscreen = true
        }
        .overlay(alignment: .bottomTrailing) {
            pageIndicator
        }
    }
    
    private func pageImage(url: String, index: Int) -> some View {
        DynamicSizeCachedAsyncImage(
            urlString: url,
            placeholder: nil,
            onSizeChange: { size in
                handleSizeChange(size: size, for: index)
            },
            expiration: DefaultCacheExpiration.illustDetail
        )
        .aspectRatio(aspectRatioForPage(index), contentMode: .fit)
    }
    
    private func handleSizeChange(size: CGSize, for index: Int) {
        guard size.width > 0 && size.height > 0 else { return }
        pageSizes[index] = size
        if index == currentPage {
            currentAspectRatio = size.width / size.height
        }
    }
    
    private func aspectRatioForPage(_ page: Int) -> CGFloat {
        if let size = pageSizes[page], size.width > 0 && size.height > 0 {
            return size.width / size.height
        }
        return CGFloat(illust.width) / CGFloat(illust.height)
    }
    
    private func updateAspectRatio(for page: Int) {
        let newRatio = aspectRatioForPage(page)
        if newRatio != currentAspectRatio {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentAspectRatio = newRatio
            }
        }
    }
    
    private var pageIndicator: some View {
        Text("\(currentPage + 1) / \(imageURLs.count)")
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding(8)
    }
    
    private func formatDateTime(_ dateString: String) -> String {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        if let parsedDate = formatter.date(from: dateString) {
            let displayFormatter = Foundation.DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return displayFormatter.string(from: parsedDate)
        }
        
        return dateString
    }
    
    private var authorSection: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: UserDetailView(userId: illust.user.id.stringValue)) {
                HStack(spacing: 12) {
                    CachedAsyncImage(
                        urlString: illust.user.profileImageUrls?.px50x50
                            ?? illust.user.profileImageUrls?.medium,
                        expiration: DefaultCacheExpiration.userAvatar
                    )
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(illust.user.name)
                            .font(.headline)
                        
                        Text("@\(illust.user.account)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(action: toggleFollow) {
                ZStack {
                    Text(isFollowed ? "已关注" : "关注")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .frame(width: 95)
                        .opacity(isFollowLoading ? 0 : 1)
                    
                    if isFollowLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .buttonStyle(GlassButtonStyle(color: isFollowed ? nil : .blue))
            .disabled(isFollowLoading)
            .sensoryFeedback(.impact(weight: .medium), trigger: isFollowed)
        }
        .padding(.vertical, 8)
        .task {
            if illust.user.isFollowed == nil {
                do {
                    let detail = try await PixivAPI.shared.getUserDetail(userId: illust.user.id.stringValue)
                    illust.user.isFollowed = detail.user.isFollowed
                } catch {
                    print("Failed to fetch user detail: \(error)")
                }
            }
        }
    }
    
    private func toggleFollow() {
        Task {
            isFollowLoading = true
            defer { isFollowLoading = false }
            
            let userId = illust.user.id.stringValue
            
            do {
                if isFollowed {
                    try await PixivAPI.shared.unfollowUser(userId: userId)
                    isFollowed = false
                    illust.user.isFollowed = false
                } else {
                    try await PixivAPI.shared.followUser(userId: userId)
                    isFollowed = true
                    illust.user.isFollowed = true
                }
            } catch {
                print("Follow toggle failed: \(error)")
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { isCommentsPanelPresented = true }) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("查看评论")
                    if let totalComments = illust.totalComments, totalComments > 0 {
                        Text("(\(totalComments))")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // 收藏按钮，点按公开收藏/取消，长按弹出菜单
            Button(action: {
                if isBookmarked {
                    bookmarkIllust(forceUnbookmark: true)
                } else {
                    bookmarkIllust(isPrivate: false)
                }
            }) {
                HStack {
                    Image(systemName: bookmarkIconName)
                        .foregroundColor(isBookmarked ? .red : .primary)
                    Text(isBookmarked ? "已收藏" : "收藏")
                        .foregroundColor(isBookmarked ? .red : .primary)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1))
                .cornerRadius(8)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isBookmarked)
            .contextMenu {
                if isBookmarked {
                    if illust.bookmarkRestrict == "private" {
                        Button(action: { bookmarkIllust(isPrivate: false) }) {
                            Label("切换为公开收藏", systemImage: "heart")
                        }
                    } else {
                        Button(action: { bookmarkIllust(isPrivate: true) }) {
                            Label("切换为非公开收藏", systemImage: "heart.slash")
                        }
                    }
                    Button(role: .destructive, action: { bookmarkIllust(forceUnbookmark: true) }) {
                        Label("取消收藏", systemImage: "heart.slash")
                    }
                } else {
                    Button(action: { bookmarkIllust(isPrivate: false) }) {
                        Label("公开收藏", systemImage: "heart")
                    }
                    Button(action: { bookmarkIllust(isPrivate: true) }) {
                        Label("非公开收藏", systemImage: "heart.slash")
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签")
                .font(.headline)
                .foregroundColor(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(illust.tags, id: \.name) { tag in
                    Button(action: {
                        let searchTag = SearchTag(name: tag.name, translatedName: tag.translatedName)
                        searchStore.addHistory(searchTag)
                        selectedTag = tag.name
                        navigateToSearch = true
                    }) {
                        TagChip(tag: tag)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(action: {
                            copyToClipboard(tag.name)
                        }) {
                            Label("复制 tag", systemImage: "doc.on.doc")
                        }
                        
                        Button(action: {
                            try? userSettingStore.addBlockedTagWithInfo(tag.name, translatedName: tag.translatedName)
                            showBlockTagToast = true
                            dismiss()
                        }) {
                            Label("屏蔽 tag", systemImage: "eye.slash")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("简介")
                .font(.headline)
                .foregroundColor(.secondary)
            
            TranslatableText(text: TextCleaner.cleanDescription(illust.caption), font: .body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func shareIllust() {
        guard let url = URL(string: "https://www.pixiv.net/artworks/\(illust.id)") else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }

    private func bookmarkIllust(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
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

    private func fetchRelatedIllusts() {
        isLoadingRelated = true
        relatedIllustError = nil
        relatedNextUrl = nil
        hasMoreRelated = true

        Task {
            do {
                let result = try await PixivAPI.shared.getRelatedIllusts(illustId: illust.id)
                await MainActor.run {
                    self.relatedIllusts = result.illusts
                    self.relatedNextUrl = result.nextUrl
                    self.hasMoreRelated = result.nextUrl != nil
                    self.isLoadingRelated = false
                }
            } catch {
                await MainActor.run {
                    self.relatedIllustError = error.localizedDescription
                    self.isLoadingRelated = false
                }
            }
        }
    }

    private func loadMoreRelatedIllusts() {
        guard let nextUrl = relatedNextUrl, !isFetchingMoreRelated && hasMoreRelated else { return }
        
        isFetchingMoreRelated = true
        
        Task {
            do {
                let result = try await PixivAPI.shared.getIllustsByURL(nextUrl)
                await MainActor.run {
                    self.relatedIllusts.append(contentsOf: result.illusts)
                    self.relatedNextUrl = result.nextUrl
                    self.hasMoreRelated = result.nextUrl != nil
                    self.isFetchingMoreRelated = false
                }
            } catch {
                await MainActor.run {
                    self.isFetchingMoreRelated = false
                }
            }
        }
    }

    private var relatedIllustsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.horizontal)
                .padding(.bottom, 8)

            Text("相关推荐")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if isLoadingRelated {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 200)
            } else if relatedIllustError != nil {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.secondary)
                        Text("加载失败")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("重试") {
                            fetchRelatedIllusts()
                        }
                        .buttonStyle(.bordered)
                    }
                    Spacer()
                }
                .frame(height: 200)
            } else if relatedIllusts.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无相关推荐")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 100)
            } else {
                WaterfallGrid(data: relatedIllusts, columnCount: 3) { relatedIllust in
                    RelatedIllustCard(illust: relatedIllust, showTitle: false) {
                        navigateToIllust = relatedIllust
                        showRelatedIllustDetail = true
                    }
                }
                .padding(.horizontal, 12)

                if hasMoreRelated {
                    HStack {
                        Spacer()
                        ProgressView()
                            .id(relatedNextUrl)
                            .onAppear {
                                loadMoreRelatedIllusts()
                            }
                        Spacer()
                    }
                    .padding(.vertical)
                }
            }
        }
        .padding(.bottom, 30)
        .navigationDestination(isPresented: $showRelatedIllustDetail) {
            if let illust = navigateToIllust {
                IllustDetailView(illust: illust)
            }
        }
    }
}

struct FullscreenImageView: View {
    let imageURLs: [String]
    @Binding var initialPage: Int
    @Binding var isPresented: Bool
    var animation: Namespace.ID
    @State private var currentPage: Int = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentPage) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                    ZoomableAsyncImage(urlString: url) {
                        isPresented = false
                    }
                    .tag(index)
                }
            }
            .ignoresSafeArea()
            #if canImport(UIKit)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            #endif
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
                
                if imageURLs.count > 1 {
                    Text("\(currentPage + 1) / \(imageURLs.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            currentPage = initialPage
        }
        .onChange(of: currentPage) { _, newValue in
            initialPage = newValue
        }
    }
}

#Preview {
    NavigationStack {
        IllustDetailView(illust: Illusts(
            id: 123,
            title: "示例插画",
            type: "illust",
            imageUrls: ImageUrls(
                squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p0_square1200.jpg",
                medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
                large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
            ),
            caption: "这是一段<strong>示例</strong>插画描述，包含HTML标签测试。",
            restrict: 0,
            user: User(
                profileImageUrls: ProfileImageUrls(
                    px16x16: "https://i.pximg.net/c/16x16/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                    px50x50: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                    px170x170: "https://i.pximg.net/c/170x170/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
                ),
                id: StringIntValue.string("1"),
                name: "示例用户",
                account: "test_user"
            ),
            tags: [
                Tag(name: "原创", translatedName: "original"),
                Tag(name: "イラスト", translatedName: "插画"),
                Tag(name: "原创角色")
            ],
            tools: ["Clip Studio Paint"],
            createDate: "2023-12-15T00:00:00+09:00",
            pageCount: 1,
            width: 1200,
            height: 1600,
            sanityLevel: 2,
            xRestrict: 0,
            metaSinglePage: MetaSinglePage(originalImageUrl: "https://i.pximg.net/img-original/d/2023/12/15/12/34/56/999999_p0.jpg"),
            metaPages: [],
            totalView: 12345,
            totalBookmarks: 999,
            isBookmarked: false,
            bookmarkRestrict: nil,
            visible: true,
            isMuted: false,
            illustAIType: 0
        ))
    }
}

#Preview("多页插画") {
    NavigationStack {
        IllustDetailView(illust: Illusts(
            id: 124,
            title: "多页示例插画",
            type: "illust",
            imageUrls: ImageUrls(
                squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p0_square1200.jpg",
                medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
                large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
            ),
            caption: "",
            restrict: 0,
            user: User(
                profileImageUrls: ProfileImageUrls(
                    px16x16: "https://i.pximg.net/c/16x16/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                    px50x50: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                    px170x170: "https://i.pximg.net/c/170x170/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
                ),
                id: StringIntValue.string("1"),
                name: "示例用户",
                account: "test_user"
            ),
            tags: [],
            tools: [],
            createDate: "2023-12-15T00:00:00+09:00",
            pageCount: 3,
            width: 1200,
            height: 1600,
            sanityLevel: 2,
            xRestrict: 0,
            metaSinglePage: nil,
            metaPages: [
                MetaPages(imageUrls: MetaPagesImageUrls(
                    squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p0_square1200.jpg",
                    medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
                    large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg",
                    original: "https://i.pximg.net/img-original/d/2023/12/15/12/34/56/999999_p0.jpg"
                )),
                MetaPages(imageUrls: MetaPagesImageUrls(
                    squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p1_square1200.jpg",
                    medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p1.jpg",
                    large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p1_master1200.jpg",
                    original: "https://i.pximg.net/img-original/d/2023/12/15/12/34/56/999999_p1.jpg"
                )),
                MetaPages(imageUrls: MetaPagesImageUrls(
                    squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p2_square1200.jpg",
                    medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p2.jpg",
                    large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p2_master1200.jpg",
                    original: "https://i.pximg.net/img-original/d/2023/12/15/12/34/56/999999_p2.jpg"
                ))
            ],
            totalView: 12345,
            totalBookmarks: 999,
            isBookmarked: false,
            bookmarkRestrict: nil,
            visible: true,
            isMuted: false,
            illustAIType: 0
        ))
    }
}

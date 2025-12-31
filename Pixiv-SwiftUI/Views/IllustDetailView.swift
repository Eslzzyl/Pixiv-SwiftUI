import SwiftUI

/// 插画详情页
struct IllustDetailView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    let illust: Illusts
    @State private var currentPage = 0
    @State private var isCommentsPanelPresented = false
    @State private var isFullscreen = false
    @State private var showCopyToast = false
    @State private var isFollowLoading = false
    @StateObject private var searchStore = SearchStore()
    @State private var selectedTag: String?
    @State private var navigateToSearch = false
    @Namespace private var animation
    @Environment(\.dismiss) private var dismiss

    private var isMultiPage: Bool {
        illust.pageCount > 1 || !illust.metaPages.isEmpty
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
                imageSection

                VStack(alignment: .leading, spacing: 16) {
                    // 标题
                    Text(illust.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .textSelection(.enabled)

                    // 作者
                    authorSection
                        .padding(.vertical, -4) // 调整间距

                    // 操作按钮
                    actionButtons

                    // 统计信息与 ID
                    VStack(alignment: .leading, spacing: 8) {
                        statsRow
                        
                        HStack(spacing: 8) {
                            Text("ID: \(String(illust.id))")
                                .textSelection(.enabled)
                            
                            Button(action: {
                                copyToClipboard(String(illust.id))
                            }) {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.plain)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

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
                .padding(.bottom, 30)
            }
        }
        .ignoresSafeArea(edges: .top)
        #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isCommentsPanelPresented) {
            CommentsPanelView(illust: illust, isPresented: $isCommentsPanelPresented)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { copyToClipboard(String(illust.id)) }) {
                        Label("复制 ID", systemImage: "doc.on.doc")
                    }

                    Button(action: shareIllust) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }

                    Button(action: bookmarkIllust) {
                        Label(
                            illust.isBookmarked ? "取消收藏" : "收藏",
                            systemImage: illust.isBookmarked ? "heart.slash" : "heart"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            preloadAllImages()
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
        
        if ImageCache.shared.cachedData(for: url) != nil {
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("https://www.pixiv.net", forHTTPHeaderField: "Referer")
        request.addValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .returnCacheDataElseLoad
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if data.count > 1000 {
                ImageCache.shared.store(data: data, for: url)
            }
        } catch {
        }
    }
    
    private var imageSection: some View {
        ZStack(alignment: .bottomTrailing) {
            if isMultiPage {
                TabView(selection: $currentPage) {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                        CachedAsyncImage(urlString: url)
                            .tag(index)
                    }
                }
                #if canImport(UIKit)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .frame(maxWidth: .infinity)
                .aspectRatio(CGFloat(illust.width) / CGFloat(illust.height), contentMode: .fit)
                .onTapGesture {
                    isFullscreen = true
                }
                
                Text("\(currentPage + 1) / \(imageURLs.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(8)
            } else {
                CachedAsyncImage(urlString: ImageURLHelper.getImageURL(from: illust, quality: 2))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(CGFloat(illust.width) / CGFloat(illust.height), contentMode: .fit)
                    .onTapGesture {
                        isFullscreen = true
                    }
            }
        }
    }
    
    private var statsRow: some View {
        HStack(spacing: 24) {
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .foregroundColor(.secondary)
                Text(NumberFormatter.formatCount(illust.totalView))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 4) {
                Image(systemName: illust.isBookmarked ? "heart.fill" : "heart")
                    .foregroundColor(illust.isBookmarked ? .red : .secondary)
                Text(NumberFormatter.formatCount(illust.totalBookmarks))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                Text(formatDateTime(illust.createDate))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .font(.caption)
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
                            ?? illust.user.profileImageUrls?.medium
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
                if isFollowLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(illust.user.isFollowed == true ? "已关注" : "关注")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(illust.user.isFollowed == true ? .secondary : .blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(illust.user.isFollowed == true ? Color.gray.opacity(0.2) : Color.blue.opacity(0.1))
                        .cornerRadius(16)
                }
            }
            .disabled(isFollowLoading)
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
            let isFollowed = illust.user.isFollowed ?? false
            
            do {
                if isFollowed {
                    try await PixivAPI.shared.unfollowUser(userId: userId)
                    illust.user.isFollowed = false
                } else {
                    try await PixivAPI.shared.followUser(userId: userId)
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
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Button(action: bookmarkIllust) {
                HStack {
                    Image(systemName: illust.isBookmarked ? "heart.fill" : "heart")
                        .foregroundColor(illust.isBookmarked ? .red : .primary)
                    Text(illust.isBookmarked ? "已收藏" : "收藏")
                        .foregroundColor(illust.isBookmarked ? .red : .primary)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
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
                }
            }
        }
    }
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("简介")
                .font(.headline)
                .foregroundColor(.secondary)
            
            CommentTextView(TextCleaner.cleanDescription(illust.caption))
        }
    }
    
    private func shareIllust() {
        guard let url = URL(string: "https://www.pixiv.net/artworks/\(illust.id)") else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }

    private func bookmarkIllust() {
        let isBookmarked = illust.isBookmarked
        let illustId = illust.id
        
        // 乐观更新 UI
        illust.isBookmarked.toggle()
        if isBookmarked {
            illust.totalBookmarks -= 1
        } else {
            illust.totalBookmarks += 1
        }
        
        Task {
            do {
                if isBookmarked {
                    try await PixivAPI.shared.deleteBookmark(illustId: illustId)
                } else {
                    try await PixivAPI.shared.addBookmark(illustId: illustId)
                }
            } catch {
                // 失败回滚
                await MainActor.run {
                    illust.isBookmarked = isBookmarked
                    if isBookmarked {
                        illust.totalBookmarks += 1
                    } else {
                        illust.totalBookmarks -= 1
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
            visible: true,
            isMuted: false,
            illustAIType: 0
        ))
    }
}

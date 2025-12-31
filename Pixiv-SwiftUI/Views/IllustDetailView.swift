import SwiftUI

/// 插画详情页
struct IllustDetailView: View {
    let illust: Illusts
    @State private var currentPage = 0
    @State private var isCommentsPanelPresented = false
    @State private var isFullscreen = false
    @Namespace private var animation
    @Environment(\.dismiss) private var dismiss

    private var isMultiPage: Bool {
        illust.pageCount > 1 || !illust.metaPages.isEmpty
    }

    private var imageURLs: [String] {
        if !illust.metaPages.isEmpty {
            return illust.metaPages.compactMap { $0.imageUrls?.original }
        } else if let originalUrl = illust.metaSinglePage?.originalImageUrl {
            return [originalUrl]
        }
        return [ImageURLHelper.getImageURL(from: illust, quality: 2)]
    }

    var body: some View {
        ZStack {
            ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                imageSection

                VStack(alignment: .leading, spacing: 12) {
                    Text(illust.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    statsRow

                    Divider()

                    authorSection

                    viewCommentsButton

                    Divider()

                    tagsSection

                    if !illust.caption.isEmpty {
                        Divider()
                        captionSection
                    }
                }
                .padding()
            }
        }
        #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isCommentsPanelPresented) {
            CommentsPanelView(illust: illust, isPresented: $isCommentsPanelPresented)
        }
        .onAppear {
            preloadAllImages()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
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
        .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
        .toolbar(isFullscreen ? .hidden : .visible, for: .tabBar)
        #endif
        
        if isFullscreen {
            FullscreenImageView(
                imageURLs: imageURLs,
                initialPage: $currentPage,
                isPresented: $isFullscreen,
                animation: animation
            )
            .zIndex(1)
        }
    }
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
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
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
        .font(.subheadline)
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
            
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var viewCommentsButton: some View {
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
            .foregroundColor(.blue)
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
                    HStack(spacing: 4) {
                        Text(tag.translatedName ?? tag.name)
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(16)
                }
            }
        }
    }
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("简介")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(TextCleaner.decodeHTMLEntities(illust.caption))
                .font(.body)
                .foregroundColor(.primary)
        }
    }
    
    private func shareIllust() {
        guard let url = URL(string: "https://www.pixiv.net/artworks/\(illust.id)") else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }

    private func bookmarkIllust() {
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

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                self.size.width = max(self.size.width, currentX)
            }
            
            self.size.height = currentY + lineHeight
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

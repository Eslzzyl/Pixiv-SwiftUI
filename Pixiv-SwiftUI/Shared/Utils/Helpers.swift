import Foundation
import SwiftUI
import Kingfisher
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private typealias KFImage = Kingfisher.KFImage
private typealias KFSource = Kingfisher.Source

/// 使用 KingfisherManager 加载图片的异步图片组件（轻量版，无 KFImage 包装器）
///
/// 与旧版 KFImage 方案相比：
/// - 无 @StateObject ImageBinder 观察者
/// - 无内置 ZStack identity 工作区
/// - 无复杂的占位→加载→完成状态机
/// - 使用高优先级任务加载当前显示图片
/// - 直接将 UIImage 存储在 @State 中，避免 KFImage 的视图树开销
public struct CachedAsyncImage: View {
    public let urlString: String?
    public let placeholder: AnyView?
    public var aspectRatio: CGFloat?
    public var contentMode: SwiftUI.ContentMode
    public var idealWidth: CGFloat?
    public var expiration: CacheExpiration
    public var targetCache: ImageCache?
    /// 是否在图片加载完成时执行淡入动画
    public var shouldAnimateLoad: Bool

    @State private var loadedImage: KFCrossPlatformImage?
    @State private var loadedImageURL: String?

    public init(
        urlString: String?,
        placeholder: AnyView? = nil,
        aspectRatio: CGFloat? = nil,
        contentMode: SwiftUI.ContentMode = .fill,
        idealWidth: CGFloat? = nil,
        expiration: CacheExpiration? = nil,
        targetCache: ImageCache? = nil,
        shouldAnimateLoad: Bool = true
    ) {
        self.urlString = urlString
        self.placeholder = placeholder
        self.aspectRatio = aspectRatio
        self.contentMode = contentMode
        self.idealWidth = idealWidth
        self.expiration = expiration ?? .days(7)
        self.targetCache = targetCache
        self.shouldAnimateLoad = shouldAnimateLoad
    }

    public var body: some View {
        ZStack {
            placeholderView

            if let urlString,
               URL(string: urlString) != nil,
               !urlString.isEmpty,
               let image = loadedImage,
               loadedImageURL == urlString {
                #if canImport(UIKit)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(shouldAnimateLoad ? .opacity : .identity)
                #elseif canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(shouldAnimateLoad ? .opacity : .identity)
                #endif
            }
        }
        .aspectRatio(aspectRatio, contentMode: contentMode)
        .clipped()
        .task(id: urlString, priority: .userInitiated) {
            loadedImage = nil
            loadedImageURL = nil
            await loadImage(for: urlString)
        }
    }

    private func loadImage(for urlString: String?) async {
        guard let urlString, let url = URL(string: urlString), !urlString.isEmpty else { return }

        var options: KingfisherOptionsInfo = [
            .requestModifier(PixivImageLoader.shared),
            .cacheOriginalImage,
            .diskCacheExpiration(expiration.kingfisherExpiration),
            .memoryCacheExpiration(expiration.kingfisherExpiration),
            .asyncCacheTypeCheck,
            .downloadPriority(ImageRequestPriority.visible)
        ]

        if let processor = downsamplingProcessor {
            options.append(.processor(processor))
        }
        if let targetCache = targetCache {
            options.append(.targetCache(targetCache))
        }

        let source: Source
        if shouldUseDirectConnection(url: url) {
            source = .provider(DirectImageDataProvider(url: url, priority: ImageRequestPriority.visible))
        } else {
            source = .network(url)
        }

        let cacheKey = source.cacheKey
        await MainActor.run {
            ImagePrefetchCoordinator.shared.removePending(cacheKey: cacheKey)
        }

        if let result = try? await KingfisherManager.shared.retrieveImage(
            with: source,
            options: options
        ) {
            // 视图可能已在 Kingfisher 缓存命中时消失，检查 Task 取消避免更新已释放的 @State
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if shouldAnimateLoad {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        loadedImage = result.image
                        loadedImageURL = urlString
                    }
                } else {
                    loadedImage = result.image
                    loadedImageURL = urlString
                }
            }
        }
    }

    /// 降采样处理器：根据 idealWidth 和卡片的屏幕像素尺寸生成缩略图，大幅降低内存占用
    private var downsamplingProcessor: DownsamplingImageProcessor? {
        guard let idealWidth = idealWidth, idealWidth > 0 else { return nil }
        let scale: CGFloat = {
#if canImport(UIKit)
            return UIScreen.main.scale
#elseif canImport(AppKit)
            return NSScreen.main?.backingScaleFactor ?? 2.0
#else
            return 2.0
#endif
        }()
        let targetWidth = idealWidth * scale
        let targetHeight: CGFloat
        if let ratio = aspectRatio, ratio > 0, ratio.isFinite {
            targetHeight = targetWidth / ratio
        } else {
            // 没有宽高比时使用 2 倍宽度作为上限（罕见的超长图场景）
            targetHeight = targetWidth * 2
        }
        let size = CGSize(width: targetWidth, height: targetHeight)
        // 仅当目标尺寸合理时才降采样（避免对极小/无效尺寸的图片产生副作用）
        guard size.width >= 50 && size.height >= 50 else { return nil }
        return DownsamplingImageProcessor(size: size)
    }

    private func shouldUseDirectConnection(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return NetworkModeStore.shared.useDirectConnection &&
               (host.contains("i.pximg.net") || host.contains("img-master.pixiv.net"))
    }

    @ViewBuilder
    private var placeholderView: some View {
        if let placeholder = placeholder {
            placeholder
                .aspectRatio(aspectRatio, contentMode: contentMode)
        } else {
            let safeAspectRatio = (aspectRatio ?? 0) > 0 ? (aspectRatio ?? 1.0) : 1.0
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(safeAspectRatio, contentMode: .fill)
        }
    }
}

/// 使用 Kingfisher 的支持尺寸回调的异步图片组件
public struct DynamicSizeCachedAsyncImage: View {
    public let urlString: String?
    public let placeholder: AnyView?
    public var aspectRatio: CGFloat?
    public var contentMode: SwiftUI.ContentMode
    public var onSizeChange: ((CGSize) -> Void)?
    public var expiration: CacheExpiration

    public init(
        urlString: String?,
        placeholder: AnyView? = nil,
        aspectRatio: CGFloat? = nil,
        contentMode: SwiftUI.ContentMode = .fill,
        onSizeChange: ((CGSize) -> Void)? = nil,
        expiration: CacheExpiration? = nil
    ) {
        self.urlString = urlString
        self.placeholder = placeholder
        self.aspectRatio = aspectRatio
        self.contentMode = contentMode
        self.onSizeChange = onSizeChange
        self.expiration = expiration ?? .days(7)
    }

    public var body: some View {
        Group {
            if let urlString = urlString, let url = URL(string: urlString), !urlString.isEmpty {
                buildKFImage(url: url)
                    .placeholder {
                        if let placeholder = placeholder {
                            placeholder
                                .aspectRatio(aspectRatio, contentMode: contentMode)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(aspectRatio, contentMode: .fill)
                        }
                    }
                    .fade(duration: 0.3)
                    .cacheOriginalImage()
                    .cancelOnDisappear(true)
                    .downloadPriority(ImageRequestPriority.visible)
                    .requestModifier(PixivImageLoader.shared)
                    .diskCacheExpiration(expiration.kingfisherExpiration)
                    .memoryCacheExpiration(expiration.kingfisherExpiration)
                    .onSuccess { result in
                        onSizeChange?(CGSize(width: result.image.size.width, height: result.image.size.height))
                    }
                    .resizable()
            } else {
                if let placeholder = placeholder {
                    placeholder
                        .aspectRatio(aspectRatio, contentMode: contentMode)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(aspectRatio, contentMode: .fill)
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: contentMode)
        .clipped()
    }

    private func buildKFImage(url: URL) -> KFImage {
        var image: KFImage
        if shouldUseDirectConnection(url: url) {
            image = KFImage.source(.directNetwork(url, priority: ImageRequestPriority.visible))
        } else {
            image = KFImage.source(.network(url))
        }
        var opts = image.options
        opts.asyncCacheTypeCheck = true
        image.options = opts
        return image
    }

    private func shouldUseDirectConnection(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return NetworkModeStore.shared.useDirectConnection &&
               (host.contains("i.pximg.net") || host.contains("img-master.pixiv.net"))
    }
}

/// 图片 URL 工具函数
struct ImageURLHelper {
    /// 根据质量设置获取封面图片 URL（用于列表卡片和单页详情）
    static func getImageURL(
        from illusts: Illusts,
        quality: Int,
        isPicture: Bool = true
    ) -> String {
        switch quality {
        case 0:  // 中等
            return illusts.imageUrls.medium.isEmpty
                ? illusts.imageUrls.large
                : illusts.imageUrls.medium
        case 1:  // 大
            return illusts.imageUrls.large.isEmpty
                ? illusts.imageUrls.medium
                : illusts.imageUrls.large
        case 2:  // 原始
            if let url = illusts.metaSinglePage?.originalImageUrl, !url.isEmpty {
                return url
            }
            if let url = illusts.metaPages.first?.imageUrls?.original, !url.isEmpty {
                return url
            }
            return illusts.imageUrls.large.isEmpty
                ? illusts.imageUrls.medium
                : illusts.imageUrls.large
        default:
            return illusts.imageUrls.medium.isEmpty
                ? illusts.imageUrls.large
                : illusts.imageUrls.medium
        }
    }

    /// 获取特定页面的图片 URL（用于多页详情）
    static func getPageImageURL(
        from illusts: Illusts,
        page: Int,
        quality: Int
    ) -> String? {
        guard page >= 0 && page < illusts.metaPages.count else { return nil }
        guard let urls = illusts.metaPages[page].imageUrls else { return nil }

        switch quality {
        case 0:
            return urls.medium.isEmpty ? urls.large : urls.medium
        case 1:
            return urls.large.isEmpty ? urls.medium : urls.large
        case 2:
            if !urls.original.isEmpty { return urls.original }
            return urls.large.isEmpty ? urls.medium : urls.large
        default:
            return urls.medium.isEmpty ? urls.large : urls.medium
        }
    }

    /// 预取一批 illust 的封面图片到 Kingfisher 缓存
    /// - Parameters:
    ///   - quality: 图片质量（与卡片实际显示一致）
    ///   - maxCount: 最大预取数量，默认 6（约一屏）
    ///   - offset: 从第几个开始预取，默认 0（第一张）
    @MainActor
    static func prefetchImages(from illusts: [Illusts], quality: Int, maxCount: Int = 6, offset: Int = 0) {
        let startIndex = offset
        let endIndex = min(startIndex + maxCount, illusts.count)
        guard startIndex < endIndex else { return }

        let slice = illusts[startIndex..<endIndex]
        let sources: [Kingfisher.Source] = slice.compactMap { illust in
            let urlString = getImageURL(from: illust, quality: quality)
            guard let url = URL(string: urlString) else { return nil }
            if shouldUseDirectConnection(url: url) {
                return .directNetwork(url, priority: ImageRequestPriority.background)
            }
            return .network(url)
        }

        guard !sources.isEmpty else { return }
        ImagePrefetchCoordinator.shared.enqueue(sources: sources, priority: ImageRequestPriority.background)
    }

    /// 预取多页作品的前 N 页到 Kingfisher 缓存。
    @MainActor
    static func prefetchPageImages(from illust: Illusts, quality: Int, pageCount: Int) {
        guard pageCount != 0, illust.metaPages.count > 1 else { return }

        let endIndex = pageCount < 0
            ? illust.metaPages.count
            : min(pageCount, illust.metaPages.count)
        guard endIndex > 1 else { return }

        let sources: [Kingfisher.Source] = (1..<endIndex).compactMap { index in
            guard let urlString = getPageImageURL(from: illust, page: index, quality: quality),
                  let url = URL(string: urlString) else { return nil }
            if shouldUseDirectConnection(url: url) {
                return .directNetwork(url, priority: ImageRequestPriority.prefetch)
            }
            return .network(url)
        }

        guard !sources.isEmpty else { return }
        ImagePrefetchCoordinator.shared.enqueue(sources: sources, priority: ImageRequestPriority.prefetch)
    }

    private static func shouldUseDirectConnection(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return NetworkModeStore.shared.useDirectConnection &&
               (host.contains("i.pximg.net") || host.contains("img-master.pixiv.net"))
    }
}

/// 卡片出现时预取后续图片，保持始终领先视口约 ahead 张
/// - 通过 `PrefetchTracker`（引用类型）跟踪进度，避免 @State 触发不必要的视图重绘
/// - 每个页面只需声明 `@State private var prefetchTracker = PrefetchTracker()` 并调用此函数
/// - Parameters:
///   - tracker: 引用类型追踪器，记录已预取到的位置
///   - ahead: 领先当前卡片多少张，默认 6
@MainActor
func prefetchIllustsIfNeeded(
    from currentIllust: Illusts,
    in illusts: [Illusts],
    quality: Int,
    multiPagePrefetchCount: Int,
    tracker: PrefetchTracker,
    ahead: Int = 6
) {
    ImageURLHelper.prefetchPageImages(
        from: currentIllust,
        quality: quality,
        pageCount: multiPagePrefetchCount
    )

    guard let index = illusts.firstIndex(where: { $0.id == currentIllust.id }) else { return }
    let desiredStartIndex = index + ahead
    let startIndex = max(tracker.nextPrefetchIndex, desiredStartIndex)
    guard startIndex < illusts.count else { return }

    let count = min(ahead, illusts.count - startIndex)
    tracker.nextPrefetchIndex = startIndex + count
    ImageURLHelper.prefetchImages(from: illusts, quality: quality, maxCount: count, offset: startIndex)
}

struct ImageQualityHelper {
    static let qualityLevels: [Int] = [0, 1, 2]

    static func getLowerQualityURLs(
        from illust: Illusts,
        targetQuality: Int,
        isManga: Bool = false
    ) -> [String] {
        var urls: [String] = []
        let lowerQualities = qualityLevels.filter { $0 < targetQuality }.sorted()

        for quality in lowerQualities {
            let url = ImageURLHelper.getImageURL(from: illust, quality: quality, isPicture: !isManga)
            if !url.isEmpty {
                urls.append(url)
            }
        }

        return urls
    }

    static func getLowerQualityPageURLs(
        from illust: Illusts,
        targetQuality: Int,
        page: Int
    ) -> [String] {
        var urls: [String] = []
        let lowerQualities = qualityLevels.filter { $0 < targetQuality }.sorted()

        for quality in lowerQualities {
            if let url = ImageURLHelper.getPageImageURL(from: illust, page: page, quality: quality) {
                urls.append(url)
            }
        }

        return urls
    }

    static func getAllQualityURLs(from illust: Illusts, isManga: Bool = false) -> [Int: String] {
        var urls: [Int: String] = [:]
        for quality in qualityLevels {
            let url = ImageURLHelper.getImageURL(from: illust, quality: quality, isPicture: !isManga)
            if !url.isEmpty {
                urls[quality] = url
            }
        }
        return urls
    }
}

/// 日期格式化工具
struct DateFormatterHelper {
    static func formatDate(_ date: String) -> String {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        if let parsedDate = formatter.date(from: date) {
            let displayFormatter = Foundation.DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.locale = Locale.current
            return displayFormatter.string(from: parsedDate)
        }

        return date
    }

    static func formatRelativeTime(_ date: String) -> String {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        guard let parsedDate = formatter.date(from: date) else {
            return date
        }

        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day, .hour, .minute], from: parsedDate, to: now)

        if let day = components.day, day > 0 {
            return "\(day) 天前"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour) 小时前"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute) 分钟前"
        } else {
            return "刚刚"
        }
    }
}

/// 文本清理工具
struct TextCleaner {
    /// 清理 HTML 标签
    static func stripHTMLTags(_ text: String) -> String {
        let regex = try? NSRegularExpression(pattern: "<[^>]*>", options: [])
        let range = NSRange(text.startIndex..., in: text)
        let result = regex?.stringByReplacingMatches(
            in: text, options: [], range: range, withTemplate: "")
        return result ?? text
    }

    /// 解码 HTML 实体（简化版本，不需要 AppKit）
    static func decodeHTMLEntities(_ text: String) -> String {
        // 简化实现：只处理常见的 HTML 实体
        var result = text
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        return result
    }

    /// 清理简介文本（处理换行和 HTML 实体）
    static func cleanDescription(_ text: String) -> String {
        // 1. 替换换行符
        var result = text.replacingOccurrences(of: "<br />", with: "\n")
        result = result.replacingOccurrences(of: "<br>", with: "\n")

        // 2. 移除其他 HTML 标签
        result = stripHTMLTags(result)

        // 3. 解码 HTML 实体
        result = decodeHTMLEntities(result)

        return result
    }
}

/// 数值格式化工具
struct NumberFormatter {
    static func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return String(count)
        }
    }

    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

/// 验证工具
struct Validator {
    /// 验证邮箱格式
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }

    /// 验证用户名格式
    static func isValidUsername(_ username: String) -> Bool {
        return !username.trimmingCharacters(in: .whitespaces).isEmpty && username.count >= 3
    }
}

/// 懒加载视图包装器 — 将视图的创建延迟到 body 首次渲染时
struct LazyView<Content: View>: View {
    private let build: () -> Content

    init(_ build: @escaping @autoclosure () -> Content) {
        self.build = build
    }

    var body: some View {
        build()
    }
}

// MARK: - 过滤设置变化监听

struct FilterSettingsChangeModifier: ViewModifier {
    let settingStore: UserSettingStore
    let onChange: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: settingStore.userSetting.r18DisplayMode) { _, _ in onChange() }
            .onChange(of: settingStore.userSetting.r18gDisplayMode) { _, _ in onChange() }
            .onChange(of: settingStore.userSetting.spoilerDisplayMode) { _, _ in onChange() }
            .onChange(of: settingStore.userSetting.aiDisplayMode) { _, _ in onChange() }
            .onChange(of: settingStore.blockedTags) { _, _ in onChange() }
            .onChange(of: settingStore.blockedUsers) { _, _ in onChange() }
            .onChange(of: settingStore.blockedIllusts) { _, _ in onChange() }
    }
}

extension View {
    /// 监听所有影响插画过滤/模糊/隐藏的用户设置属性，
    /// 当其中任何一个变化时触发 `onChange` 回调，确保 cached filtered 数据及时更新。
    func onFilterSettingsChange(from settingStore: UserSettingStore, perform action: @escaping () -> Void) -> some View {
        modifier(FilterSettingsChangeModifier(settingStore: settingStore, onChange: action))
    }
}

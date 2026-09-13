import Foundation
import Kingfisher
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 亮点详情页收录作品的尺寸/宽高比缓存
///
/// 用于在图片加载前及视图回收复用时提供稳定的宽高比，
/// 避免瀑布流或列表滚动时因占位尺寸与真实图片尺寸不一致产生跳动。
@MainActor
final class SpotlightWorkLayoutCache {
    static let shared = SpotlightWorkLayoutCache()

    private var cache: [String: CGFloat] = [:]

    private init() {}

    /// 获取作品图片的宽高比
    func aspectRatio(for urlString: String) -> CGFloat? {
        if let cached = cache[urlString] {
            return cached
        }
        if let image = KingfisherManager.shared.cache.retrieveImageInMemoryCache(forKey: urlString) {
            let ratio = image.size.width / image.size.height
            if ratio > 0 && ratio.isFinite {
                cache[urlString] = ratio
                return ratio
            }
        }
        return nil
    }

    /// 记录作品图片的实际宽高比
    func setAspectRatio(_ ratio: CGFloat, for urlString: String) {
        guard ratio > 0 && ratio.isFinite else { return }
        cache[urlString] = ratio
    }
}

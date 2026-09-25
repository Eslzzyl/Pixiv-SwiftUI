import SwiftUI
import Kingfisher

#if canImport(UIKit)
import UIKit

struct ZoomableScrollView: UIViewRepresentable {
    let image: UIImage
    var onSingleTap: () -> Void
    @Binding var isZoomed: Bool
    var onDragProgress: ((CGFloat) -> Void)?
    var onDragEnded: ((Bool) -> Void)?

    func makeUIView(context: Context) -> CenteredScrollView {
        let scrollView = CenteredScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)

        let singleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.require(toFail: doubleTapGesture)
        scrollView.addGestureRecognizer(singleTapGesture)

        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.delegate = context.coordinator
        scrollView.addGestureRecognizer(panGesture)
        context.coordinator.panGesture = panGesture

        return scrollView
    }

    func updateUIView(_ uiView: CenteredScrollView, context: Context) {
        if let imageView = context.coordinator.imageView {
            if imageView.image != image {
                imageView.image = image
                imageView.frame = CGRect(origin: .zero, size: image.size)
                uiView.contentSize = image.size
                uiView.hasConfiguredZoom = false
            }
            uiView.setNeedsLayout()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class CenteredScrollView: UIScrollView {
        fileprivate var hasConfiguredZoom = false
        private var lastConfiguredBoundsSize: CGSize = .zero

        override func layoutSubviews() {
            super.layoutSubviews()

            let currentBoundsSize = bounds.size
            if !hasConfiguredZoom || lastConfiguredBoundsSize != currentBoundsSize {
                if currentBoundsSize.width > 0, currentBoundsSize.height > 0 {
                    configureZoomScale()
                    hasConfiguredZoom = true
                    lastConfiguredBoundsSize = currentBoundsSize
                }
            }

            centerImage()
        }

        func configureZoomScale() {
            guard let imageView = subviews.first(where: { $0 is UIImageView }) as? UIImageView,
                  let image = imageView.image else { return }

            let boundsSize = bounds.size
            let xScale = boundsSize.width / image.size.width
            let yScale = boundsSize.height / image.size.height
            let minScale = min(xScale, yScale)

            minimumZoomScale = minScale
            maximumZoomScale = 3.0

            // 首次配置或 bounds 改变时重置 zoom 到适应屏幕的尺寸
            zoomScale = minScale
        }

        func centerImage() {
            guard let imageView = subviews.first(where: { $0 is UIImageView }) as? UIImageView else { return }

            let boundsSize = bounds.size
            guard boundsSize.width > 0, boundsSize.height > 0 else { return }

            var frameToCenter = imageView.frame

            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2.0
            } else {
                frameToCenter.origin.x = 0
            }

            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2.0
            } else {
                frameToCenter.origin.y = 0
            }

            imageView.frame = frameToCenter
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var parent: ZoomableScrollView
        var imageView: UIImageView?
        var panGesture: UIPanGestureRecognizer?
        private var isDraggingToDismiss = false
        private var startPanPoint: CGPoint = .zero

        init(_ parent: ZoomableScrollView) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView, let imageView = imageView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let pointInView = gesture.location(in: imageView)
                let newZoomScale = scrollView.maximumZoomScale
                let scrollViewSize = scrollView.bounds.size

                let widthValue = scrollViewSize.width / newZoomScale
                let heightValue = scrollViewSize.height / newZoomScale
                let xValue = pointInView.x - (widthValue / 2.0)
                let yValue = pointInView.y - (heightValue / 2.0)

                let rectToZoomTo = CGRect(x: xValue, y: yValue, width: widthValue, height: heightValue)
                scrollView.zoom(to: rectToZoomTo, animated: true)
            }
        }

        @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            parent.onSingleTap()
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let zoomed = scrollView.zoomScale > scrollView.minimumZoomScale + 0.01
            if parent.isZoomed != zoomed {
                parent.isZoomed = zoomed
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }

            let translation = gesture.translation(in: scrollView)
            let velocity = gesture.velocity(in: scrollView)
            let deadZone: CGFloat = 15

            switch gesture.state {
            case .began:
                startPanPoint = translation
                isDraggingToDismiss = false

            case .changed:
                guard !parent.isZoomed else {
                    isDraggingToDismiss = false
                    return
                }

                if translation.y > deadZone {
                    if !isDraggingToDismiss {
                        isDraggingToDismiss = true
                    }
                    let screenHeight = scrollView.bounds.height
                    let progress = min(translation.y / screenHeight, 1.0)
                    parent.onDragProgress?(progress)
                } else if translation.y <= 0 {
                    if isDraggingToDismiss {
                        parent.onDragProgress?(0)
                    }
                    isDraggingToDismiss = false
                }
                // translation.y 在 0 ~ deadZone 之间时保持当前状态（滞后）

            case .ended, .cancelled:
                if isDraggingToDismiss {
                    let screenHeight = scrollView.bounds.height
                    let threshold: CGFloat = 0.25
                    let progress = translation.y / screenHeight
                    let shouldDismiss = progress > threshold || velocity.y > 500

                    parent.onDragEnded?(shouldDismiss)
                    isDraggingToDismiss = false
                }

            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === panGesture {
                guard let scrollView = gestureRecognizer.view as? UIScrollView else { return false }
                let velocity = (gestureRecognizer as? UIPanGestureRecognizer)?.velocity(in: scrollView) ?? .zero
                // 仅当未缩放且纯向下滑动时启动关闭手势；
                // 水平/斜向滑动直接拒绝，确保 TabView 翻页手势独占触摸序列
                return !parent.isZoomed && velocity.y > abs(velocity.x) && velocity.y > 0
            }
            return true
        }
    }
}

struct ZoomableAsyncImage: View {
    let urlString: String
    var fallbackURL: String?
    var aspectRatio: CGFloat?
    var onDismiss: () -> Void
    var expiration: CacheExpiration?
    var onFallbackUpgraded: (() -> Void)?
    @Binding var isZoomed: Bool
    var onDragProgress: ((CGFloat) -> Void)?
    var onDragEnded: ((Bool) -> Void)?

    @State private var uiImage: UIImage?
    @State private var fallbackUIImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        GeometryReader { _ in
            if let uiImage = uiImage {
                // Target quality image loaded — show it
                ZoomableScrollView(
                    image: uiImage,
                    onSingleTap: onDismiss,
                    isZoomed: $isZoomed,
                    onDragProgress: onDragProgress,
                    onDragEnded: onDragEnded
                )
            } else if let fallbackImage = fallbackUIImage {
                // Fallback (detail quality) available — show it while upgrading
                ZoomableScrollView(
                    image: fallbackImage,
                    onSingleTap: onDismiss,
                    isZoomed: $isZoomed,
                    onDragProgress: onDragProgress,
                    onDragEnded: onDragEnded
                )
            } else {
                // Nothing loaded yet — show black to avoid flash on black background
                Color.black
            }
        }
        .task {
            await loadImages()
        }
    }

    @MainActor
    private func loadImages() async {
        // Phase 1: Load fallback (detail quality) from cache — instant if cached
        if let fallbackURL = fallbackURL, let url = URL(string: fallbackURL) {
            let fallbackSource: Source = shouldUseDirectConnection(url: url)
                ? .directNetwork(url)
                : .network(Kingfisher.KF.ImageResource(downloadURL: url))

            // Try cache first for instant display
            if let cached = try? await KingfisherManager.shared.retrieveImage(
                with: fallbackSource,
                options: [.onlyFromCache, .requestModifier(PixivImageLoader.shared)]
            ) {
                fallbackUIImage = cached.image
                isLoading = false
            } else {
                // Fallback not cached — load it from network to show something
                let fallbackOptions: KingfisherOptionsInfo = CacheConfig.options(expiration: .hours(1)) + [
                    .requestModifier(PixivImageLoader.shared)
                ]
                if let result = try? await KingfisherManager.shared.retrieveImage(
                    with: fallbackSource,
                    options: fallbackOptions
                ) {
                    fallbackUIImage = result.image
                    isLoading = false
                }
            }
        }

        // Phase 2: Load target (zoom quality) — may need network
        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }

        let exp = expiration ?? .days(7)
        let options: KingfisherOptionsInfo = CacheConfig.options(expiration: exp) + [
            .requestModifier(PixivImageLoader.shared)
        ]

        let source: Source = shouldUseDirectConnection(url: url)
            ? .directNetwork(url)
            : .network(Kingfisher.KF.ImageResource(downloadURL: url))

        do {
            let result = try await KingfisherManager.shared.retrieveImage(with: source, options: options)
            uiImage = result.image
            isLoading = false
            onFallbackUpgraded?()
        } catch {
            isLoading = false
            // Keep showing fallback if available
        }
    }

    private func shouldUseDirectConnection(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return NetworkModeStore.shared.useDirectConnection &&
               PixivNetworkConfiguration.isPixivImageHost(host)
    }
}
#else
struct ZoomableAsyncImage: View {
    let urlString: String
    var fallbackURL: String?
    var aspectRatio: CGFloat?
    var onDismiss: () -> Void
    var isZoomed: Binding<Bool>
    var onDragProgress: ((CGFloat) -> Void)?
    var onDragEnded: ((Bool) -> Void)?

    var body: some View {
        CachedAsyncImage(
            urlString: fallbackURL ?? urlString,
            aspectRatio: aspectRatio,
            contentMode: .fit
        )
        .onTapGesture {
            onDismiss()
        }
    }
}
#endif

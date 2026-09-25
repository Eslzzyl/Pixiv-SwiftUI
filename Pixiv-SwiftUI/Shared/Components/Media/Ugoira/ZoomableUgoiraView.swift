import SwiftUI
import Kingfisher

#if canImport(UIKit)
import UIKit

// MARK: - ZoomableUgoiraView

/// A UIViewRepresentable that combines UIScrollView zoom/pan with ugoira frame animation.
/// Used inside FullscreenImageView to provide a zoomable animated ugoira experience.
struct ZoomableUgoiraView: UIViewRepresentable {
    let frameURLs: [URL]
    let frameDelays: [TimeInterval]
    let aspectRatio: CGFloat
    let expiration: CacheExpiration
    var onSingleTap: () -> Void
    @Binding var isZoomed: Bool
    var onDragProgress: ((CGFloat) -> Void)?
    var onDragEnded: ((Bool) -> Void)?

    init(
        frameURLs: [URL],
        frameDelays: [TimeInterval],
        aspectRatio: CGFloat,
        expiration: CacheExpiration = .hours(1),
        onSingleTap: @escaping () -> Void,
        isZoomed: Binding<Bool>,
        onDragProgress: ((CGFloat) -> Void)? = nil,
        onDragEnded: ((Bool) -> Void)? = nil
    ) {
        self.frameURLs = frameURLs
        self.frameDelays = frameDelays
        self.aspectRatio = aspectRatio
        self.expiration = expiration
        self.onSingleTap = onSingleTap
        self._isZoomed = isZoomed
        self.onDragProgress = onDragProgress
        self.onDragEnded = onDragEnded
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> CenteredScrollView {
        let scrollView = CenteredScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        let doubleTapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)

        let singleTapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSingleTap(_:))
        )
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.require(toFail: doubleTapGesture)
        scrollView.addGestureRecognizer(singleTapGesture)

        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panGesture.delegate = context.coordinator
        scrollView.addGestureRecognizer(panGesture)
        context.coordinator.panGesture = panGesture

        // Try to load the first frame from cache immediately
        // so the scroll view has a valid image for zoom configuration
        context.coordinator.loadCachedFirstFrame()

        // Start playback
        context.coordinator.startPlayback()

        return scrollView
    }

    func updateUIView(_ uiView: CenteredScrollView, context: Context) {
        // No update needed — frame animation is driven by the coordinator
    }

    static func dismantleUIView(_ uiView: CenteredScrollView, coordinator: Coordinator) {
        coordinator.stopPlayback()
    }
}

// MARK: - CenteredScrollView

extension ZoomableUgoiraView {
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
}

// MARK: - Coordinator

extension ZoomableUgoiraView {
    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var parent: ZoomableUgoiraView
        var imageView: UIImageView?
        var panGesture: UIPanGestureRecognizer?
        private var isDraggingToDismiss = false
        private var startPanPoint: CGPoint = .zero

        // Frame animation state
        private var currentFrameIndex: Int = 0
        private var displayLink: CADisplayLink?
        private var lastFrameTime: CFTimeInterval = 0
        private var accumulatedTime: CFTimeInterval = 0
        private var isPlaying = true
        private var hasLoadedInitialFrame = false

        init(_ parent: ZoomableUgoiraView) {
            self.parent = parent
        }

        // MARK: - UIScrollViewDelegate

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let zoomed = scrollView.zoomScale > scrollView.minimumZoomScale + 0.01
            if parent.isZoomed != zoomed {
                parent.isZoomed = zoomed
            }
        }

        // MARK: - Gesture Handlers

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView,
                  let imageView = imageView,
                  let image = imageView.image else { return }

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

        // MARK: - UIGestureRecognizerDelegate

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            return true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === panGesture {
                guard let scrollView = gestureRecognizer.view as? UIScrollView else { return false }
                let velocity = (gestureRecognizer as? UIPanGestureRecognizer)?.velocity(in: scrollView) ?? .zero
                return !parent.isZoomed && velocity.y > abs(velocity.x) && velocity.y > 0
            }
            return true
        }

        // MARK: - Frame Animation

        func startPlayback() {
            displayLink = CADisplayLink(
                target: DisplayLinkTarget { [weak self] timestamp in
                    self?.updateFrame(at: timestamp)
                },
                selector: #selector(DisplayLinkTarget.handleDisplayLink(_:))
            )
            displayLink?.add(to: .main, forMode: .common)
        }

        func stopPlayback() {
            displayLink?.invalidate()
            displayLink = nil
        }

        /// Load the first frame from Kingfisher cache synchronously if available.
        /// Called during makeUIView so the scroll view has a valid image immediately.
        func loadCachedFirstFrame() {
            guard !parent.frameURLs.isEmpty else { return }
            let url = parent.frameURLs[0]
            let cacheKey = url.absoluteString

            // Try memory cache first (instant)
            if let cached = KingfisherManager.shared.cache.retrieveImageInMemoryCache(forKey: cacheKey) {
                setFrameImage(cached)
                hasLoadedInitialFrame = true
                return
            }

            // Not in memory — schedule an async cache check + network fallback
            Task { @MainActor in
                let source = Source.pixivNetwork(url)

                let options: KingfisherOptionsInfo = [.onlyFromCache] +
                    CacheConfig.options(expiration: parent.expiration)

                if let result = try? await KingfisherManager.shared.retrieveImage(
                    with: source,
                    options: options
                ) {
                    setFrameImage(result.image)
                    hasLoadedInitialFrame = true
                } else {
                    // Not cached at all — load from network
                    loadFrameImage(at: url) { [weak self] image in
                        guard let self = self, let image = image else { return }
                        self.setFrameImage(image)
                        self.hasLoadedInitialFrame = true
                    }
                }
            }
        }

        private func updateFrame(at timestamp: CFTimeInterval) {
            guard hasLoadedInitialFrame, !parent.frameURLs.isEmpty else { return }

            if lastFrameTime == 0 {
                lastFrameTime = timestamp
                return
            }

            guard currentFrameIndex < parent.frameDelays.count else {
                lastFrameTime = timestamp
                return
            }
            let frameDuration = parent.frameDelays[currentFrameIndex]
            let deltaTime = timestamp - lastFrameTime
            accumulatedTime += deltaTime

            if accumulatedTime >= frameDuration {
                accumulatedTime = 0
                let nextIndex = currentFrameIndex + 1
                if nextIndex >= parent.frameURLs.count {
                    currentFrameIndex = 0
                } else {
                    currentFrameIndex = nextIndex
                }

                let url = parent.frameURLs[currentFrameIndex]
                loadFrameImage(at: url) { [weak self] image in
                    guard let self = self, let image = image else { return }
                    self.setFrameImage(image)
                }
            }

            lastFrameTime = timestamp
        }

        private func setFrameImage(_ image: UIImage) {
            guard let imageView = self.imageView else { return }

            imageView.image = image

            // Set initial frame/size if this is the first image
            if imageView.frame.size == .zero {
                imageView.frame = CGRect(origin: .zero, size: image.size)
                if let scrollView = imageView.superview as? CenteredScrollView {
                    scrollView.contentSize = image.size
                    scrollView.hasConfiguredZoom = false
                    scrollView.setNeedsLayout()
                }
                return
            }

            // For subsequent frames, only update the image content without reconfiguring zoom
            // (all ugoira frames from the same zip have identical dimensions)
        }

        private func loadFrameImage(at url: URL, completion: @escaping (UIImage?) -> Void) {
            let source = Source.pixivNetwork(url)

            let options: KingfisherOptionsInfo = CacheConfig.options(expiration: parent.expiration)

            KingfisherManager.shared.retrieveImage(with: source, options: options) { result in
                switch result {
                case .success(let value):
                    completion(value.image)
                case .failure:
                    completion(nil)
                }
            }
        }

    }
}

// MARK: - DisplayLinkTarget

private final class DisplayLinkTarget {
    private let callback: (CFTimeInterval) -> Void

    init(callback: @escaping (CFTimeInterval) -> Void) {
        self.callback = callback
    }

    @objc func handleDisplayLink(_ displayLink: CADisplayLink) {
        callback(displayLink.timestamp)
    }
}

// MARK: - SwiftUI Wrapper

/// A SwiftUI wrapper around ZoomableUgoiraView for easy use in FullscreenImageView.
struct ZoomableUgoiraContent: View {
    let frameURLs: [URL]
    let frameDelays: [TimeInterval]
    let aspectRatio: CGFloat
    let expiration: CacheExpiration
    let onDismiss: () -> Void
    @Binding var isZoomed: Bool
    var onDragProgress: ((CGFloat) -> Void)?
    var onDragEnded: ((Bool) -> Void)?

    var body: some View {
        ZoomableUgoiraView(
            frameURLs: frameURLs,
            frameDelays: frameDelays,
            aspectRatio: aspectRatio,
            expiration: expiration,
            onSingleTap: onDismiss,
            isZoomed: $isZoomed,
            onDragProgress: onDragProgress,
            onDragEnded: onDragEnded
        )
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
}

#else
// MARK: - macOS stub

struct ZoomableUgoiraContent: View {
    let frameURLs: [URL]
    let frameDelays: [TimeInterval]
    let aspectRatio: CGFloat
    let expiration: CacheExpiration
    let onDismiss: () -> Void
    @Binding var isZoomed: Bool
    var onDragProgress: ((CGFloat) -> Void)?
    var onDragEnded: ((Bool) -> Void)?

    var body: some View {
        UgoiraView(
            frameURLs: frameURLs,
            frameDelays: frameDelays,
            aspectRatio: aspectRatio,
            expiration: expiration,
            shouldAutoPlay: true
        )
        .onTapGesture { onDismiss() }
    }
}
#endif

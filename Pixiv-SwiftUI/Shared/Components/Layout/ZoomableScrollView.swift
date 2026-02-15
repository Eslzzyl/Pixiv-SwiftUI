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
        scrollView.maximumZoomScale = 3.0
        scrollView.minimumZoomScale = 1.0
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
            }
            uiView.setNeedsLayout()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class CenteredScrollView: UIScrollView {
        override func layoutSubviews() {
            super.layoutSubviews()
            centerImage()
        }

        func centerImage() {
            guard let imageView = subviews.first(where: { $0 is UIImageView }) as? UIImageView,
                  let image = imageView.image else { return }

            let boundsSize = bounds.size
            if boundsSize.width == 0 || boundsSize.height == 0 { return }

            let imageSize = image.size
            let xScale = boundsSize.width / imageSize.width
            let yScale = boundsSize.height / imageSize.height
            let minScale = min(xScale, yScale)

            if minimumZoomScale != minScale {
                minimumZoomScale = minScale
                if zoomScale < minScale || (zoomScale == 1.0 && minScale < 1.0) {
                    zoomScale = minScale
                }
            }

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

            switch gesture.state {
            case .began:
                startPanPoint = translation
                isDraggingToDismiss = !parent.isZoomed && translation.y > 0

            case .changed:
                guard !parent.isZoomed else {
                    isDraggingToDismiss = false
                    return
                }

                if translation.y > 0 {
                    isDraggingToDismiss = true
                    let screenHeight = scrollView.bounds.height
                    let progress = min(translation.y / screenHeight, 1.0)
                    parent.onDragProgress?(progress)
                } else {
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

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === panGesture {
                guard let scrollView = gestureRecognizer.view as? UIScrollView else { return true }
                let velocity = (gestureRecognizer as? UIPanGestureRecognizer)?.velocity(in: scrollView) ?? .zero

                if !parent.isZoomed && velocity.y > abs(velocity.x) && velocity.y > 0 {
                    return true
                }
            }
            return true
        }
    }
}

struct ZoomableAsyncImage: View {
    let urlString: String
    var aspectRatio: CGFloat?
    var onDismiss: () -> Void
    var expiration: CacheExpiration?
    @Binding var isZoomed: Bool
    var onDragProgress: ((CGFloat) -> Void)?
    var onDragEnded: ((Bool) -> Void)?

    @State private var uiImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        GeometryReader { _ in
            if let uiImage = uiImage {
                ZoomableScrollView(
                    image: uiImage,
                    onSingleTap: onDismiss,
                    isZoomed: $isZoomed,
                    onDragProgress: onDragProgress,
                    onDragEnded: onDragEnded
                )
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))

                    ProgressView()
                }
                .aspectRatio(aspectRatio ?? 1.0, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }

        let exp = expiration ?? .days(7)
        let options: KingfisherOptionsInfo = CacheConfig.options(expiration: exp) + [
            .transition(.fade(0.5))
        ]

        let source: Source = shouldUseDirectConnection(url: url)
            ? .directNetwork(url)
            : .network(Kingfisher.KF.ImageResource(downloadURL: url))

        do {
            let result = try await KingfisherManager.shared.retrieveImage(with: source, options: options)
            uiImage = result.image
            isLoading = false
        } catch {
            isLoading = false
        }
    }

    private func shouldUseDirectConnection(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return NetworkModeStore.shared.useDirectConnection &&
               (host.contains("i.pximg.net") || host.contains("img-master.pixiv.net"))
    }
}
#else
struct ZoomableAsyncImage: View {
    let urlString: String
    var aspectRatio: CGFloat?
    var onDismiss: () -> Void
    var isZoomed: Binding<Bool>
    var onDragProgress: ((CGFloat) -> Void)?
    var onDragEnded: ((Bool) -> Void)?

    var body: some View {
        CachedAsyncImage(
            urlString: urlString,
            aspectRatio: aspectRatio,
            contentMode: .fit
        )
        .onTapGesture {
            onDismiss()
        }
    }
}
#endif

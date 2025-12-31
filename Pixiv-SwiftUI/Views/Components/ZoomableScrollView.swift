import SwiftUI
#if canImport(UIKit)
import UIKit

struct ZoomableScrollView: UIViewRepresentable {
    let image: UIImage
    var onSingleTap: () -> Void
    
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
        
        // Double tap to zoom
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
        
        // Single tap to dismiss/action
        let singleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.require(toFail: doubleTapGesture)
        scrollView.addGestureRecognizer(singleTapGesture)
        
        return scrollView
    }
    
    func updateUIView(_ uiView: CenteredScrollView, context: Context) {
        if let imageView = context.coordinator.imageView {
            if imageView.image != image {
                imageView.image = image
                imageView.frame = CGRect(origin: .zero, size: image.size)
                uiView.contentSize = image.size
            }
            // 强制布局更新
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
            
            // 计算最小缩放比例，使图片完全显示
            let boundsSize = bounds.size
            if boundsSize.width == 0 || boundsSize.height == 0 { return }
            
            let imageSize = image.size
            let xScale = boundsSize.width / imageSize.width
            let yScale = boundsSize.height / imageSize.height
            let minScale = min(xScale, yScale)
            
            // 如果当前缩放比例小于计算出的最小比例，或者从未设置过（默认1.0可能不合适），则更新
            // 注意：这里需要小心不要在用户缩放时重置
            // 简单的策略：如果 contentSize 还没适配 bounds，或者 zoomScale 明显不对
            
            // 实际上，我们应该设置 minimumZoomScale
            if minimumZoomScale != minScale {
                minimumZoomScale = minScale
                // 如果当前是初始状态（比如 zoomScale == 1.0 且 1.0 不是 minScale），或者小于 minScale
                if zoomScale < minScale || (zoomScale == 1.0 && minScale < 1.0) {
                    zoomScale = minScale
                }
            }
            
            // 居中逻辑
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
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableScrollView
        var imageView: UIImageView?
        
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
                // Zoom to tap point
                let pointInView = gesture.location(in: imageView)
                let newZoomScale = scrollView.maximumZoomScale
                let scrollViewSize = scrollView.bounds.size
                
                let w = scrollViewSize.width / newZoomScale
                let h = scrollViewSize.height / newZoomScale
                let x = pointInView.x - (w / 2.0)
                let y = pointInView.y - (h / 2.0)
                
                let rectToZoomTo = CGRect(x: x, y: y, width: w, height: h)
                scrollView.zoom(to: rectToZoomTo, animated: true)
            }
        }
        
        @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            parent.onSingleTap()
        }
    }
}

struct ZoomableAsyncImage: View {
    let urlString: String
    var onDismiss: () -> Void
    
    @State private var uiImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        GeometryReader { proxy in
            if let uiImage = uiImage {
                ZoomableScrollView(image: uiImage, onSingleTap: onDismiss)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }
        
        if let cachedData = ImageCache.shared.cachedData(for: url) {
            DispatchQueue.global(qos: .userInitiated).async {
                if let image = UIImage(data: cachedData) {
                    DispatchQueue.main.async {
                        self.uiImage = image
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            }
            return
        }
        
        isLoading = true
        
        var request = URLRequest(url: url)
        request.addValue("https://www.pixiv.net", forHTTPHeaderField: "Referer")
        request.addValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .returnCacheDataElseLoad
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data {
                DispatchQueue.global(qos: .userInitiated).async {
                    if let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            ImageCache.shared.store(data: data, for: url)
                            self.uiImage = image
                            self.isLoading = false
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.isLoading = false
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }
}
#endif

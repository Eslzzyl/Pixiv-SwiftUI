#if os(iOS)
import SwiftUI
import UIKit

struct IllustDetailRegionSwipeView: UIViewRepresentable {
    let excludedFrame: CGRect
    let fallbackAspectRatio: CGFloat
    let isMultiPage: Bool
    let isFirstPage: Bool
    let isLastPage: Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void
    let onCancelled: () -> Void

    init(
        excludedFrame: CGRect = .zero,
        fallbackAspectRatio: CGFloat = 1.0,
        isMultiPage: Bool = false,
        isFirstPage: Bool = true,
        isLastPage: Bool = true,
        onChanged: @escaping (CGFloat) -> Void,
        onEnded: @escaping (CGFloat, CGFloat) -> Void,
        onCancelled: @escaping () -> Void
    ) {
        self.excludedFrame = excludedFrame
        self.fallbackAspectRatio = fallbackAspectRatio
        self.isMultiPage = isMultiPage
        self.isFirstPage = isFirstPage
        self.isLastPage = isLastPage
        self.onChanged = onChanged
        self.onEnded = onEnded
        self.onCancelled = onCancelled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            excludedFrame: excludedFrame,
            fallbackAspectRatio: fallbackAspectRatio,
            isMultiPage: isMultiPage,
            isFirstPage: isFirstPage,
            isLastPage: isLastPage,
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled
        )
    }

    func makeUIView(context: Context) -> SwipeCaptureView {
        let view = SwipeCaptureView(coordinator: context.coordinator)
        context.coordinator.captureViewReference = view
        return view
    }

    func updateUIView(_ uiView: SwipeCaptureView, context: Context) {
        context.coordinator.excludedFrame = excludedFrame
        context.coordinator.fallbackAspectRatio = fallbackAspectRatio
        context.coordinator.isMultiPage = isMultiPage
        context.coordinator.isFirstPage = isFirstPage
        context.coordinator.isLastPage = isLastPage
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.onCancelled = onCancelled
        context.coordinator.captureViewReference = uiView
        uiView.coordinateNavigationGesturesIfNeeded()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var excludedFrame: CGRect
        var fallbackAspectRatio: CGFloat
        var isMultiPage: Bool
        var isFirstPage: Bool
        var isLastPage: Bool
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat, CGFloat) -> Void
        var onCancelled: () -> Void
        weak var captureViewReference: SwipeCaptureView?

        init(
            excludedFrame: CGRect,
            fallbackAspectRatio: CGFloat,
            isMultiPage: Bool,
            isFirstPage: Bool,
            isLastPage: Bool,
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (CGFloat, CGFloat) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            self.excludedFrame = excludedFrame
            self.fallbackAspectRatio = fallbackAspectRatio
            self.isMultiPage = isMultiPage
            self.isFirstPage = isFirstPage
            self.isLastPage = isLastPage
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled
        }

        @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let view = gestureRecognizer.view else { return }
            let translation = gestureRecognizer.translation(in: view).x

            switch gestureRecognizer.state {
            case .began:
                cancelScrollViewPanGestures(in: view)
                onChanged(translation)
            case .changed:
                onChanged(translation)
            case .ended:
                let velocity = gestureRecognizer.velocity(in: view).x
                onEnded(translation, velocity)
            case .cancelled, .failed:
                onCancelled()
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer,
                  let view = gestureRecognizer.view
            else { return false }

            let velocity = panGestureRecognizer.velocity(in: view)
            // 1. Must be primarily horizontal
            guard abs(velocity.x) > abs(velocity.y) * 1.2 else {
                return false
            }

            let location = panGestureRecognizer.location(in: view)
            // 2. Exclude left edge to preserve interactivePopGestureRecognizer
            let edgeThreshold: CGFloat = 30
            guard location.x >= edgeThreshold else {
                return false
            }

            // 3. Determine if touch is inside the image area
            var isInsideImage = false
            if let window = view.window {
                let windowLocation = view.convert(location, to: window)
                if excludedFrame != .zero {
                    isInsideImage = excludedFrame.contains(windowLocation)
                } else {
                    let safeTop = window.safeAreaInsets.top
                    let estimatedHeight = view.bounds.width / max(fallbackAspectRatio, 0.1)
                    let estimatedRect = CGRect(x: 0, y: safeTop, width: view.bounds.width, height: estimatedHeight)
                    isInsideImage = estimatedRect.contains(windowLocation)
                }
            }

            if isInsideImage {
                if isMultiPage {
                    let isSwipingRight = velocity.x > 0
                    let isSwipingLeft = velocity.x < 0

                    if isFirstPage && isSwipingRight {
                        // 首页向右滑动：切换到上一幅插画
                        return true
                    } else if isLastPage && isSwipingLeft {
                        // 最后一页向左滑动：切换到下一幅插画
                        return true
                    } else {
                        // 其他情况换页：交由 TabView 处理
                        return false
                    }
                } else {
                    // 单页插画：图片区域滑动支持切换插画
                    return true
                }
            }

            // 图片外部区域（信息/标签/评论等）：左右滑动均支持切换插画
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            otherGestureRecognizer.view is UIScrollView
        }

        private func cancelScrollViewPanGestures(in root: UIView) {
            for subview in root.subviews {
                if let scrollView = subview as? UIScrollView {
                    scrollView.panGestureRecognizer.isEnabled = false
                    scrollView.panGestureRecognizer.isEnabled = true
                }
                cancelScrollViewPanGestures(in: subview)
            }
        }
    }

    final class SwipeCaptureView: UIView {
        private let coordinator: Coordinator
        fileprivate let panGestureRecognizer: UIPanGestureRecognizer
        private weak var coordinatedViewController: UIViewController?
        private weak var disabledContentPopGestureRecognizer: UIGestureRecognizer?
        private var contentPopGestureWasEnabled: Bool?

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            panGestureRecognizer = UIPanGestureRecognizer()
            super.init(frame: .zero)
            backgroundColor = .clear
            isUserInteractionEnabled = false
            panGestureRecognizer.addTarget(coordinator, action: #selector(Coordinator.handlePan(_:)))
            panGestureRecognizer.delegate = coordinator
            panGestureRecognizer.cancelsTouchesInView = false
            coordinator.captureViewReference = self
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordinateNavigationGesturesIfNeeded()
        }

        func coordinateNavigationGesturesIfNeeded() {
            guard let targetVC = parentViewController ?? parentNavigationController else { return }

            if coordinatedViewController !== targetVC || panGestureRecognizer.view !== targetVC.view {
                panGestureRecognizer.view?.removeGestureRecognizer(panGestureRecognizer)
                coordinatedViewController = targetVC
                targetVC.view.addGestureRecognizer(panGestureRecognizer)
            }

            if let navigationController = targetVC.navigationController ?? (targetVC as? UINavigationController) {
                navigationController.interactivePopGestureRecognizer?.isEnabled = true

                if #available(iOS 26.0, *) {
                    if let interactiveContentPop = navigationController.interactiveContentPopGestureRecognizer {
                        if disabledContentPopGestureRecognizer !== interactiveContentPop {
                            disabledContentPopGestureRecognizer = interactiveContentPop
                            contentPopGestureWasEnabled = interactiveContentPop.isEnabled
                        }
                        interactiveContentPop.isEnabled = false
                    }
                }
            }
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            if newWindow == nil {
                panGestureRecognizer.view?.removeGestureRecognizer(panGestureRecognizer)
                restoreContentPopGestureRecognizer()
                coordinatedViewController = nil
            }
            super.willMove(toWindow: newWindow)
        }

        private func restoreContentPopGestureRecognizer() {
            guard let gestureRecognizer = disabledContentPopGestureRecognizer,
                  let wasEnabled = contentPopGestureWasEnabled
            else { return }
            gestureRecognizer.isEnabled = wasEnabled
            disabledContentPopGestureRecognizer = nil
            contentPopGestureWasEnabled = nil
        }

        private var parentViewController: UIViewController? {
            var responder: UIResponder? = self
            while let nextResponder = responder?.next {
                if let viewController = nextResponder as? UIViewController {
                    return viewController
                }
                responder = nextResponder
            }
            return nil
        }

        fileprivate var parentNavigationController: UINavigationController? {
            var responder: UIResponder? = self
            while let nextResponder = responder?.next {
                if let viewController = nextResponder as? UIViewController {
                    return viewController.navigationController ?? (viewController as? UINavigationController)
                }
                responder = nextResponder
            }
            return nil
        }
    }
}

#Preview("详情区域手势") {
    Color.clear
        .frame(height: 120)
        .background {
            IllustDetailRegionSwipeView(
                onChanged: { _ in },
                onEnded: { _, _ in },
                onCancelled: { }
            )
        }
}
#endif

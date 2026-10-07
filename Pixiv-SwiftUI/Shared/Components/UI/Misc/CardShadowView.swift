import SwiftUI

#if canImport(UIKit)
import UIKit

/// 高性能卡片阴影组件
///
/// 通过 UIViewRepresentable 桥接到 CALayer 并设置 `shadowPath`，
/// 避免 SwiftUI `.shadow()` 修饰符产生的动态阴影 offscreen pass。
///
/// ## 原理
/// SwiftUI 的 `.shadow()` 在每一帧都需要 GPU 通过离屏渲染推断阴影形状。
/// 而 CALayer 的 `shadowPath` 直接指定精确路径，让 Core Animation
/// 跳过形状推断阶段，消除离屏 pass。
///
/// Apple Tech Talk 10857 "Demystify and eliminate hitches in the render phase"
/// 确认：设置 shadowPath 可消除动态阴影的 offscreen passes。
///
/// ## 使用
/// ```swift
/// YourCardView
///     .cornerRadius(16)
///     .background(CardShadowView(cornerRadius: 16))
/// ```
struct CardShadowView: UIViewRepresentable {
    let cornerRadius: CGFloat
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowOffset: CGSize

    init(
        cornerRadius: CGFloat = 16,
        shadowColor: Color = .black.opacity(0.2),
        shadowRadius: CGFloat = 2,
        shadowOffset: CGSize = CGSize(width: 0, height: 2)
    ) {
        self.cornerRadius = cornerRadius
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
    }

    func makeUIView(context: Context) -> ShadowUIView {
        let view = ShadowUIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: ShadowUIView, context: Context) {
        uiView.cornerRadius = cornerRadius
        uiView.shadowColor = UIColor(shadowColor)
        uiView.shadowRadius = shadowRadius
        uiView.shadowOffset = shadowOffset
        uiView.updateShadowPath()
    }
}

final class ShadowUIView: UIView {
    var cornerRadius: CGFloat = 16
    var shadowColor: UIColor = UIColor.black.withAlphaComponent(0.2)
    var shadowRadius: CGFloat = 2
    var shadowOffset: CGSize = CGSize(width: 0, height: 2)
    private var cachedBounds: CGRect = .null
    private var cachedCornerRadius: CGFloat?

    override func layoutSubviews() {
        super.layoutSubviews()
        updateShadowPath()
    }

    /// 设置 CALayer 阴影属性，核心优化是 `shadowPath`
    func updateShadowPath() {
        let pathChanged = cachedBounds != bounds || cachedCornerRadius != cornerRadius
        if pathChanged {
            layer.shadowPath = UIBezierPath(
                roundedRect: bounds,
                cornerRadius: cornerRadius
            ).cgPath
            cachedBounds = bounds
            cachedCornerRadius = cornerRadius
        }
        let resolvedColor = shadowColor.resolvedColor(with: traitCollection)
        if layer.shadowColor != resolvedColor.cgColor {
            layer.shadowColor = resolvedColor.cgColor
        }
        if layer.shadowOpacity != 1.0 {
            layer.shadowOpacity = 1.0
        }
        if layer.shadowRadius != shadowRadius {
            layer.shadowRadius = shadowRadius
        }
        if layer.shadowOffset != shadowOffset {
            layer.shadowOffset = shadowOffset
        }
        if layer.masksToBounds {
            layer.masksToBounds = false
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // 使用 CardShadowView 的卡片
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .frame(width: 200, height: 120)
            .overlay(Text("CardShadowView").font(.caption))
            .background(CardShadowView(cornerRadius: 16))

        // 参考：使用原生 .shadow() 的卡片
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .frame(width: 200, height: 120)
            .overlay(Text(".shadow() reference").font(.caption))
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
#elseif canImport(AppKit)
import AppKit

/// 高性能卡片阴影组件（macOS 版本）
struct CardShadowView: NSViewRepresentable {
    let cornerRadius: CGFloat
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowOffset: CGSize

    init(
        cornerRadius: CGFloat = 16,
        shadowColor: Color = .black.opacity(0.2),
        shadowRadius: CGFloat = 2,
        shadowOffset: CGSize = CGSize(width: 0, height: 2)
    ) {
        self.cornerRadius = cornerRadius
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
    }

    func makeNSView(context: Context) -> ShadowNSView {
        let view = ShadowNSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    func updateNSView(_ nsView: ShadowNSView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.shadowColor = NSColor(shadowColor)
        nsView.shadowRadius = shadowRadius
        nsView.shadowOffset = shadowOffset
        nsView.updateShadowPath()
    }
}

final class ShadowNSView: NSView {
    var cornerRadius: CGFloat = 16
    var shadowColor: NSColor = NSColor.black.withAlphaComponent(0.2)
    var shadowRadius: CGFloat = 2
    var shadowOffset: CGSize = CGSize(width: 0, height: 2)
    private var cachedBounds: CGRect = .null
    private var cachedCornerRadius: CGFloat?

    override func layout() {
        super.layout()
        updateShadowPath()
    }

    func updateShadowPath() {
        if !wantsLayer {
            wantsLayer = true
        }
        guard let layer = layer else { return }
        let pathChanged = cachedBounds != bounds || cachedCornerRadius != cornerRadius
        if pathChanged {
            layer.shadowPath = CGPath(
                roundedRect: bounds,
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            )
            cachedBounds = bounds
            cachedCornerRadius = cornerRadius
        }
        var resolvedColor: CGColor?
        effectiveAppearance.performAsCurrentDrawingAppearance {
            resolvedColor = shadowColor.cgColor
        }
        if layer.shadowColor != resolvedColor {
            layer.shadowColor = resolvedColor
        }
        if layer.shadowOpacity != 1.0 {
            layer.shadowOpacity = 1.0
        }
        if layer.shadowRadius != shadowRadius {
            layer.shadowRadius = shadowRadius
        }
        if layer.shadowOffset != shadowOffset {
            layer.shadowOffset = shadowOffset
        }
        if layer.masksToBounds {
            layer.masksToBounds = false
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(nsColor: .controlBackgroundColor))
            .frame(width: 200, height: 120)
            .overlay(Text("CardShadowView").font(.caption))
            .background(CardShadowView(cornerRadius: 16))

        RoundedRectangle(cornerRadius: 16)
            .fill(Color(nsColor: .controlBackgroundColor))
            .frame(width: 200, height: 120)
            .overlay(Text(".shadow() reference").font(.caption))
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
    }
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
}
#endif

import SwiftUI

// MARK: - Preference Key for Image Frame Capture

/// 捕获详情页中图片的全局屏幕位置与尺寸，供全屏转场与区域手势判定使用。
struct ImageFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let new = nextValue()
        if new != .zero { value = new }
    }
}

// MARK: - Convenience Extensions

extension View {
    /// 添加后台 GeometryReader 报告视图的全局 frame。
    func reportImageFrame() -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: ImageFramePreferenceKey.self,
                        value: geometry.frame(in: .global)
                    )
            }
        )
    }

    /// 在满足特定条件时报告全局 frame。
    func reportImageFrame(when condition: Bool) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: ImageFramePreferenceKey.self,
                        value: condition ? geometry.frame(in: .global) : .zero
                    )
            }
        )
    }
}

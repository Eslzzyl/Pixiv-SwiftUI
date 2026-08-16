import SwiftUI

#if DEBUG && os(macOS)
struct IllustLayoutFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func reportIllustDetailLayoutFrame(_ name: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: IllustLayoutFramePreferenceKey.self,
                    value: [name: proxy.frame(in: .global)]
                )
            }
        )
    }
}
#endif

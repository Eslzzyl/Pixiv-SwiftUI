#if os(macOS)
import AppKit
import SwiftUI

/// A macOS vertical scroll container that reserves the system scrollbar width from the first layout.
///
/// This keeps width-dependent content, such as `FlowLayout`, from reflowing when asynchronous
/// content makes the scrollbar appear.
struct MacOSStableScrollView<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let scrollBarWidth = NSScroller.scrollerWidth(
                for: .regular,
                scrollerStyle: NSScroller.preferredScrollerStyle
            )
            let contentWidth = max(0, proxy.size.width - scrollBarWidth)

            ScrollView(.vertical) {
                content()
                    .frame(width: contentWidth, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    MacOSStableScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("Inspector")
                .font(.headline)

            ForEach(0..<20, id: \.self) { index in
                Text("Item \(index)")
            }
        }
        .padding()
    }
    .frame(width: 320, height: 480)
}
#endif

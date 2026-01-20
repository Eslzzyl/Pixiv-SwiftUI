import SwiftUI

extension View {
    @ViewBuilder
    func popoverCompactify() -> some View {
        #if os(macOS)
        self.frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
            .fixedSize(horizontal: false, vertical: true)
        #else
        self
        #endif
    }
}

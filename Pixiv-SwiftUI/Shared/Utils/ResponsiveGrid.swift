import SwiftUI

enum ResponsiveGrid {
    static func columnCount(
        for containerWidth: CGFloat,
        userSetting: UserSetting? = nil
    ) -> Int {
        if let setting = userSetting {
            #if os(macOS)
            if !setting.hCrossAdapt {
                return setting.hCrossCount
            }
            #elseif canImport(UIKit)
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            if isPad && !setting.hCrossAdapt {
                return setting.hCrossCount
            } else if !isPad && !setting.crossAdapt {
                return setting.crossCount
            }
            #endif
        }

        #if os(macOS)
        switch containerWidth {
        case 0..<600:
            return 2
        case 600..<900:
            return 3
        case 900..<1200:
            return 4
        case 1200..<1600:
            return 5
        default:
            return 6
        }
        #elseif canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
            ? (containerWidth >= 1024 ? 5 : 4)
            : (containerWidth >= 414 ? 3 : 2)
        #endif
    }
}

struct ResponsiveGridModifier: ViewModifier {
    let userSetting: UserSetting?
    @Binding var columnCount: Int
    @State private var lastWidth: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            updateColumnCount(for: proxy.size.width)
                        }
                        .onChange(of: proxy.size.width) { _, newWidth in
                            updateColumnCount(for: newWidth)
                        }
                        .onChange(of: userSetting?.crossCount) { _, _ in updateColumnCount(for: lastWidth) }
                        .onChange(of: userSetting?.hCrossCount) { _, _ in updateColumnCount(for: lastWidth) }
                        .onChange(of: userSetting?.crossAdapt) { _, _ in updateColumnCount(for: lastWidth) }
                        .onChange(of: userSetting?.hCrossAdapt) { _, _ in updateColumnCount(for: lastWidth) }
                }
            )
    }

    private func updateColumnCount(for width: CGFloat) {
        guard width > 0 else { return }
        lastWidth = width
        columnCount = ResponsiveGrid.columnCount(for: width, userSetting: userSetting)
    }
}

extension View {
    func responsiveGridColumnCount(
        userSetting: UserSetting? = nil,
        columnCount: Binding<Int>
    ) -> some View {
        modifier(ResponsiveGridModifier(userSetting: userSetting, columnCount: columnCount))
    }
}

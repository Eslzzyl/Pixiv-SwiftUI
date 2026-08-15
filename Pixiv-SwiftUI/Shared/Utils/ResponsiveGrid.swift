import SwiftUI

enum ResponsiveGrid {
    static func columnCount(
        for containerWidth: CGFloat,
        userSetting: UserSetting? = nil
    ) -> Int {
        if let setting = userSetting {
            #if os(macOS)
            if !setting.hCrossAdapt {
                return max(setting.hCrossCount, 1)
            }
            #elseif canImport(UIKit)
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            if isPad && !setting.hCrossAdapt {
                return max(setting.hCrossCount, 1)
            } else if !isPad && !setting.crossAdapt {
                return max(setting.crossCount, 1)
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

    static func initialColumnCount(userSetting: UserSetting) -> Int {
        #if os(macOS)
        if !userSetting.hCrossAdapt {
            return max(userSetting.hCrossCount, 1)
        }
        return 4
        #elseif canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            if !userSetting.hCrossAdapt {
                return max(userSetting.hCrossCount, 1)
            }
            return 4
        } else {
            if !userSetting.crossAdapt {
                return max(userSetting.crossCount, 1)
            }
            return 2
        }
        #else
        return 2
        #endif
    }

    static func userColumnCount(for containerWidth: CGFloat) -> Int {
        #if os(macOS)
        switch containerWidth {
        case 0..<600:
            return 1
        case 600..<950:
            return 2
        case 950..<1400:
            return 3
        default:
            return 4
        }
        #elseif canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return containerWidth >= 1024 ? 3 : 2
        } else {
            return containerWidth >= 600 ? 2 : 1
        }
        #else
        return 1
        #endif
    }
}

struct ResponsiveGridModifier: ViewModifier {
    let userSetting: UserSetting?
    @Binding var columnCount: Int
    var measuredWidth: Binding<CGFloat>?
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
                        .onChange(of: userSetting) { _, _ in
                            updateColumnCount(for: lastWidth)
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
        measuredWidth?.wrappedValue = width
        columnCount = ResponsiveGrid.columnCount(for: width, userSetting: userSetting)
    }
}

struct ResponsiveUserGridModifier: ViewModifier {
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
                }
            )
    }

    private func updateColumnCount(for width: CGFloat) {
        guard width > 0 else { return }
        lastWidth = width
        columnCount = ResponsiveGrid.userColumnCount(for: width)
    }
}

extension View {
    func responsiveGridColumnCount(
        userSetting: UserSetting? = nil,
        columnCount: Binding<Int>,
        measuredWidth: Binding<CGFloat>? = nil
    ) -> some View {
        modifier(ResponsiveGridModifier(userSetting: userSetting, columnCount: columnCount, measuredWidth: measuredWidth))
    }

    func responsiveUserGridColumnCount(
        columnCount: Binding<Int>
    ) -> some View {
        modifier(ResponsiveUserGridModifier(columnCount: columnCount))
    }
}

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum ResponsiveGrid {
    static func columnCount(
        for containerWidth: CGFloat,
        userSetting: UserSetting? = nil
    ) -> Int {
        if let setting = userSetting, !usesAdaptiveColumns(setting) {
            return configuredColumnCount(userSetting: setting)
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
        if !usesAdaptiveColumns(userSetting) {
            return configuredColumnCount(userSetting: userSetting)
        }
        #if os(macOS)
        return 4
        #elseif canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2
        #else
        return 2
        #endif
    }

    /// 当前方向下用户配置的网格列数
    static func configuredColumnCount(userSetting: UserSetting) -> Int {
        #if os(macOS)
        return max(userSetting.hCrossCount, 1)
        #elseif canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return max(isPadPortrait ? userSetting.crossCount : userSetting.hCrossCount, 1)
        }
        return max(userSetting.crossCount, 1)
        #else
        return 2
        #endif
    }

    private static func usesAdaptiveColumns(_ setting: UserSetting) -> Bool {
        #if os(macOS)
        return setting.hCrossAdapt
        #elseif canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return isPadPortrait ? setting.crossAdapt : setting.hCrossAdapt
        }
        return setting.crossAdapt
        #else
        return false
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

    #if canImport(UIKit)
    /// 以当前窗口场景的宽高关系判断竖屏，随旋转即时更新
    private static var isPadPortrait: Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let scene else { return true }
        let bounds = scene.coordinateSpace.bounds
        return bounds.height >= bounds.width
    }
    #endif
}

struct ResponsiveGridModifier: ViewModifier {
    let userSetting: UserSetting?
    @Binding var columnCount: Int
    var measuredWidth: Binding<CGFloat>?
    @State private var lastWidth: CGFloat = 0

    private struct SettingSignature: Equatable {
        let crossCount: Int?
        let hCrossCount: Int?
        let crossAdapt: Bool?
        let hCrossAdapt: Bool?

        init(_ setting: UserSetting?) {
            crossCount = setting?.crossCount
            hCrossCount = setting?.hCrossCount
            crossAdapt = setting?.crossAdapt
            hCrossAdapt = setting?.hCrossAdapt
        }
    }
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
                        .onChange(of: SettingSignature(userSetting)) { _, _ in
                            updateColumnCount(for: lastWidth)
                        }
                }
            )
    }

    private func updateColumnCount(for width: CGFloat) {
        guard width > 0 else { return }
        if lastWidth != width {
            lastWidth = width
        }
        if measuredWidth?.wrappedValue != width {
            measuredWidth?.wrappedValue = width
        }
        let newColumnCount = ResponsiveGrid.columnCount(for: width, userSetting: userSetting)
        if columnCount != newColumnCount {
            columnCount = newColumnCount
        }
    }
}

struct ResponsiveUserGridModifier: ViewModifier {
    @Binding var columnCount: Int

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
        let newColumnCount = ResponsiveGrid.userColumnCount(for: width)
        if columnCount != newColumnCount {
            columnCount = newColumnCount
        }
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

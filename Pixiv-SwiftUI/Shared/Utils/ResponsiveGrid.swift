import SwiftUI

@MainActor
enum ResponsiveGrid {
    private enum WidthBand {
        case compact
        case standard
        case wide
    }

    private static let artworkMinimumCardWidth: CGFloat = 144
    private static let userMinimumCardWidth: CGFloat = 190
    private static let defaultSpacing: CGFloat = 12

    static func columnCount(
        for containerWidth: CGFloat,
        userSetting: UserSetting? = nil
    ) -> Int {
        if let setting = userSetting, setting.gridColumnMode == 1 {
            return manualColumnCount(for: containerWidth, userSetting: setting)
        }

        return adaptiveColumnCount(
            for: containerWidth,
            minimumCardWidth: artworkMinimumCardWidth,
            spacing: defaultSpacing
        )
    }

    static func initialColumnCount(userSetting: UserSetting) -> Int {
        if userSetting.gridColumnMode == 1 {
            return max(userSetting.standardGridColumnCount, 1)
        }

        return adaptiveColumnCount(
            for: 480,
            minimumCardWidth: artworkMinimumCardWidth,
            spacing: defaultSpacing
        )
    }

    static func configuredColumnCount(userSetting: UserSetting) -> Int {
        max(userSetting.standardGridColumnCount, 1)
    }

    private static func manualColumnCount(for containerWidth: CGFloat, userSetting: UserSetting) -> Int {
        switch widthBand(for: containerWidth) {
        case .compact:
            return max(userSetting.compactGridColumnCount, 1)
        case .standard:
            return max(userSetting.standardGridColumnCount, 1)
        case .wide:
            return max(userSetting.wideGridColumnCount, 1)
        }
    }

    private static func adaptiveColumnCount(
        for containerWidth: CGFloat,
        minimumCardWidth: CGFloat,
        spacing: CGFloat
    ) -> Int {
        guard containerWidth > 0 else { return 1 }
        let count = Int(floor((containerWidth + spacing) / (minimumCardWidth + spacing)))
        let maximumColumnCount: Int
        switch containerWidth {
        case 0..<600:
            maximumColumnCount = 3
        case 600..<1_200:
            maximumColumnCount = 4
        default:
            maximumColumnCount = 5
        }
        return min(max(count, 1), maximumColumnCount)
    }

    private static func widthBand(for containerWidth: CGFloat) -> WidthBand {
        switch containerWidth {
        case 0..<600:
            return .compact
        case 600..<1_000:
            return .standard
        default:
            return .wide
        }
    }

    static func userColumnCount(for containerWidth: CGFloat) -> Int {
        min(
            adaptiveColumnCount(
                for: containerWidth,
                minimumCardWidth: userMinimumCardWidth,
                spacing: defaultSpacing
            ),
            4
        )
    }
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
        let gridColumnMode: Int?
        let compactGridColumnCount: Int?
        let standardGridColumnCount: Int?
        let wideGridColumnCount: Int?

        init(_ setting: UserSetting?) {
            crossCount = setting?.crossCount
            hCrossCount = setting?.hCrossCount
            crossAdapt = setting?.crossAdapt
            hCrossAdapt = setting?.hCrossAdapt
            gridColumnMode = setting?.gridColumnMode
            compactGridColumnCount = setting?.compactGridColumnCount
            standardGridColumnCount = setting?.standardGridColumnCount
            wideGridColumnCount = setting?.wideGridColumnCount
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

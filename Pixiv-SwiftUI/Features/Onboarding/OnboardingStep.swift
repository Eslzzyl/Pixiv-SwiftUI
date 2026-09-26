import Foundation

/// 设置向导步骤定义
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome = 0
    case network = 1
    case contentFilter = 2
    case appearance = 3

    var id: Int { rawValue }

    /// 当前步骤编号（从 1 开始）
    var stepNumber: Int {
        rawValue + 1
    }

    /// 总步骤数
    static var totalSteps: Int {
        allCases.count
    }

    /// 步骤标题
    var title: String {
        switch self {
        case .welcome:
            return String(localized: "欢迎")
        case .network:
            return String(localized: "网络连接")
        case .contentFilter:
            return String(localized: "内容展示")
        case .appearance:
            return String(localized: "外观与画质")
        }
    }
}

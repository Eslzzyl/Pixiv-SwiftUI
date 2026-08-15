import Foundation

/// 认证会话协议
///
/// 提供当前登录用户的基本信息查询，供所有 Store 通过 DI 获取，
/// 替代直接访问 `AccountStore.shared`。
protocol AuthSessionProtocol: AnyObject {
    /// 当前用户 ID，未登录时返回 "guest"
    var currentUserId: String { get }

    /// 账号状态变更代次，用于丢弃账号切换前启动的异步请求结果
    var accountGeneration: UInt { get }

    /// 是否已登录
    var isLoggedIn: Bool { get }

    /// 是否已通过 Web 登录（Ajax 会话就绪）
    var isWebLoggedIn: Bool { get }

    /// 当前账号是否已配置 Ajax Web 会话
    var hasAjaxSession: Bool { get }
}

extension AuthSessionProtocol {
    func isCurrentAccount(generation: UInt, userId: String) -> Bool {
        accountGeneration == generation && currentUserId == userId
    }
}

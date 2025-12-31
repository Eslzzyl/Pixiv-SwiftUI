import Foundation
import Observation
import SwiftData

/// 账户状态管理
@Observable
final class AccountStore {
    static let shared = AccountStore()

    var currentAccount: AccountPersist?
    var accounts: [AccountPersist] = []
    var isLoggedIn: Bool = false
    var isLoading: Bool = false
    var error: AppError?

    private let dataContainer = DataContainer.shared

    private init() {
        loadAccounts()
    }

    /// 从 SwiftData 加载所有账户
    func loadAccounts() {
        let context = dataContainer.mainContext
        do {
            // 获取所有账户
            let descriptor = FetchDescriptor<AccountPersist>()
            self.accounts = try context.fetch(descriptor)

            // 设置第一个账户为当前账户
            if let firstAccount = accounts.first {
                self.currentAccount = firstAccount
                self.isLoggedIn = true
                // 设置 API token
                PixivAPI.shared.setAccessToken(firstAccount.accessToken)
            } else {
                self.currentAccount = nil
                self.isLoggedIn = false
            }
        } catch {
            self.error = AppError.databaseError("无法加载账户: \(error)")
        }
    }

    /// 使用 refresh_token 登录
    func loginWithRefreshToken(_ refreshToken: String) async {
        isLoading = true
        error = nil

        do {
            let (accessToken, user) = try await PixivAPI.shared.loginWithRefreshToken(refreshToken)

            // 创建新账户
            let account = AccountPersist(
                userId: user.id.stringValue,
                accessToken: accessToken,
                refreshToken: refreshToken,
                deviceToken: "",
                userImage: user.profileImageUrls?.px170x170 ?? user.profileImageUrls?.medium ?? ""
            )

            try saveAccount(account)
            isLoading = false
        } catch {
            self.error = AppError.networkError("登录失败: \(error.localizedDescription)")
            isLoading = false
        }
    }

    /// 保存新账户
    func saveAccount(_ account: AccountPersist) throws {
        let context = dataContainer.mainContext

        // 检查是否已存在
        let descriptor = FetchDescriptor<AccountPersist>(
            predicate: #Predicate { $0.userId == account.userId }
        )
        if let existing = try context.fetch(descriptor).first {
            // 更新已存在的账户
            existing.accessToken = account.accessToken
            existing.refreshToken = account.refreshToken
            existing.deviceToken = account.deviceToken
            existing.userImage = account.userImage
        } else {
            // 添加新账户
            context.insert(account)
        }

        try context.save()

        // 重新加载账户列表
        loadAccounts()

        // 设置为当前账户
        self.currentAccount = account
        self.isLoggedIn = true
    }

    /// 删除账户
    func deleteAccount(_ account: AccountPersist) throws {
        let context = dataContainer.mainContext

        let descriptor = FetchDescriptor<AccountPersist>(
            predicate: #Predicate { $0.userId == account.userId }
        )
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }

        loadAccounts()
    }

    /// 更新账户信息
    func updateAccount(_ account: AccountPersist) throws {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<AccountPersist>(
            predicate: #Predicate { $0.userId == account.userId }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.accessToken = account.accessToken
            existing.refreshToken = account.refreshToken
            try context.save()
        }
    }

    /// 切换当前账户
    func switchAccount(_ account: AccountPersist) {
        self.currentAccount = account
        self.isLoggedIn = true
        PixivAPI.shared.setAccessToken(account.accessToken)
    }

    /// 登出
    func logout() throws {
        if let current = currentAccount {
            try deleteAccount(current)
        }
    }

    /// 更新用户信息
    func updateUserInfo(_ userImage: String) throws {
        guard let current = currentAccount else { return }

        current.userImage = userImage
        try dataContainer.save()
    }
}

/// 应用级别的错误类型
enum AppError: LocalizedError {
    case networkError(String)
    case databaseError(String)
    case decodingError(String)
    case authenticationError(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "网络错误: \(message)"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        case .decodingError(let message):
            return "数据解析错误: \(message)"
        case .authenticationError(let message):
            return "认证错误: \(message)"
        }
    }
}

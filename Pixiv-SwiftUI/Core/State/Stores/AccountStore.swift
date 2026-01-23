import Foundation
import Observation
import SwiftData

/// 导航请求类型
enum NavigationRequest: Equatable {
    case userDetail(String)
    case illustDetail(Illusts)
}

/// 账户状态管理
@MainActor
@Observable
final class AccountStore {
    static let shared = AccountStore()

    var currentAccount: AccountPersist?
    var accounts: [AccountPersist] = []
    var isLoggedIn: Bool = false
    var isLoading: Bool = false
    var error: AppError?
    var isLoaded: Bool = false
    var showTokenRefreshFailedToast: Bool = false
    var tokenRefreshErrorMessage: String = ""

    /// 获取当前用户 ID，未登录时返回 "guest"
    var currentUserId: String {
        currentAccount?.userId ?? "guest"
    }

    private let lastUserIdKey = "last_active_user_id"

    /// 标记用户已尝试过登录（用于游客模式判断）
    private(set) var hasAttemptedLogin: Bool = false

    /// 是否为游客模式（未登录但可以浏览公开内容）
    var isGuestMode: Bool {
        !isLoggedIn && hasAttemptedLogin
    }

    /// 导航请求：用于从 Sheet 中请求主页面进行导航
    var navigationRequest: NavigationRequest?

    private let dataContainer = DataContainer.shared

    private init() {
    }

    @MainActor
    func loadAccounts() {
        let context = dataContainer.mainContext
        do {
            let descriptor = FetchDescriptor<AccountPersist>()
            self.accounts = try context.fetch(descriptor)

            let lastUserId = UserDefaults.standard.string(forKey: lastUserIdKey)

            if let savedAccount = accounts.first(where: { $0.userId == lastUserId }) {
                self.currentAccount = savedAccount
                self.isLoggedIn = true
                PixivAPI.shared.setAccessToken(savedAccount.accessToken)
            } else if let firstAccount = accounts.first {
                self.currentAccount = firstAccount
                self.isLoggedIn = true
                PixivAPI.shared.setAccessToken(firstAccount.accessToken)
                UserDefaults.standard.set(firstAccount.userId, forKey: lastUserIdKey)
            } else {
                self.currentAccount = nil
                self.isLoggedIn = false
            }
            self.isLoaded = true
        } catch {
            self.error = AppError.databaseError("无法加载账户: \(error)")
            self.isLoaded = true
        }
    }

    func loadAccountsAsync() async {
        await MainActor.run {
            loadAccounts()
        }
    }

    /// 标记用户已尝试过登录（启动时调用）
    func markLoginAttempted() {
        hasAttemptedLogin = true
    }

    /// 请求导航到指定目标
    @MainActor
    func requestNavigation(_ request: NavigationRequest) {
        self.navigationRequest = request
    }

    /// 使用 refresh_token 登录
    func loginWithRefreshToken(_ refreshToken: String) async {
        isLoading = true
        error = nil

        do {
            let (accessToken, user) = try await PixivAPI.shared.loginWithRefreshToken(refreshToken)

            // 创建新账户
            let account = AccountPersist(
                user: user,
                accessToken: accessToken,
                refreshToken: refreshToken,
                deviceToken: ""
            )

            try await saveAccount(account)
            isLoading = false
        } catch {
            self.error = AppError.networkError("登录失败: \(error.localizedDescription)")
            isLoading = false
        }
    }

    /// 使用 code 登录
    func loginWithCode(_ code: String, codeVerifier: String) async {
        isLoading = true
        error = nil

        do {
            let (accessToken, refreshToken, user) = try await PixivAPI.shared.loginWithCode(code, codeVerifier: codeVerifier)

            // 创建新账户
            let account = AccountPersist(
                user: user,
                accessToken: accessToken,
                refreshToken: refreshToken,
                deviceToken: ""
            )

            try await saveAccount(account)
            isLoading = false
        } catch {
            self.error = AppError.networkError("登录失败: \(error.localizedDescription)")
            isLoading = false
        }
    }

    /// 保存新账户
    func saveAccount(_ account: AccountPersist) async throws {
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
            existing.name = account.name
            existing.account = account.account
            existing.mailAddress = account.mailAddress
            existing.isPremium = account.isPremium
            existing.xRestrict = account.xRestrict
            existing.isMailAuthorized = account.isMailAuthorized
        } else {
            // 添加新账户
            context.insert(account)
        }

        try context.save()
        UserDefaults.standard.set(account.userId, forKey: lastUserIdKey)

        // 重新加载账户列表
        loadAccounts()

        // 设置为当前账户
        self.currentAccount = account
        self.isLoggedIn = true

        // 清理缓存并重新加载数据
        await onAccountChanged()
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
            existing.userImage = account.userImage
            existing.name = account.name
            existing.account = account.account
            existing.mailAddress = account.mailAddress
            existing.isPremium = account.isPremium
            existing.xRestrict = account.xRestrict
            existing.isMailAuthorized = account.isMailAuthorized
            try context.save()
        }
    }

    /// 切换当前账户
    func switchAccount(_ account: AccountPersist) async {
        self.currentAccount = account
        self.isLoggedIn = true
        PixivAPI.shared.setAccessToken(account.accessToken)
        UserDefaults.standard.set(account.userId, forKey: lastUserIdKey)

        await onAccountChanged()
    }

    /// 登出
    func logout() async throws {
        hasAttemptedLogin = true
        if let current = currentAccount {
            try deleteAccount(current)

            // 如果登出后没有当前账号了（说明刚才删除的是最后一个账号）
            if currentAccount == nil {
                UserDefaults.standard.removeObject(forKey: lastUserIdKey)
                PixivAPI.shared.setAccessToken("")
            }
        }

        await onAccountChanged()
    }

    /// 当账号变动（切换、登入、登出）时调用
    private func onAccountChanged() async {
        // 1. 清理内存缓存
        try? await DIContainer.shared.cacheService.clearAll()
        CacheManager.shared.clearAll()

        // 2. 清理全局 Store 的内存状态
        IllustStore.shared.clearMemoryCache()
        NovelStore.shared.clearMemoryCache()

        // 3. 重新加载当前账号的数据
        await UserSettingStore.shared.loadUserSettingAsync()
        DownloadStore.shared.loadTasks()

        // 4. 重置导航或其他全局状态
        self.navigationRequest = nil
    }

    /// 更新用户信息
    func updateUserInfo(_ userImage: String) throws {
        guard let current = currentAccount else { return }

        current.userImage = userImage
        try dataContainer.save()
    }

    /// 刷新当前账户信息
    func refreshCurrentAccount() async {
        guard let account = currentAccount else { return }

        do {
            let (accessToken, refreshToken, user) = try await PixivAPI.shared.refreshAccessToken(account.refreshToken)

            // 更新账户信息
            account.accessToken = accessToken
            account.refreshToken = refreshToken
            account.userImage = user.profileImageUrls?.px170x170 ?? user.profileImageUrls?.medium ?? ""
            account.name = user.name
            account.account = user.account
            account.mailAddress = user.mailAddress ?? ""
            account.isPremium = (user.isPremium ?? false) ? 1 : 0
            account.xRestrict = user.xRestrict ?? 0
            account.isMailAuthorized = (user.isMailAuthorized ?? false) ? 1 : 0

            try dataContainer.save()
        } catch {
            print("刷新账户信息失败: \(error)")
        }
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

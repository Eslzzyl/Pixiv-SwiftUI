import Foundation
import Observation
import SwiftData
import os.log

extension Notification.Name {
    /// 账号变更通知（切换、登入、登出）
    /// 各 Store 监听此通知以清理自身内存状态并重新加载数据
    static let accountDidChange = Notification.Name("PixivAccountDidChange")
}

/// 导航请求类型
enum NavigationRequest: Equatable {
    case userDetail(String)
    case illustDetail(Illusts)
}

/// 账户状态管理
@MainActor
@Observable
final class AccountStore: AuthSessionProtocol {
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

    /// 当前账号是否已配置 Ajax Web 会话
    var hasAjaxSession: Bool {
        guard let session = currentAccount?.webPHPSESSID else { return false }
        return !session.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private struct AjaxCookieState {
        let phpSessId: String?
        let yuidB: String?
        let pAbDId: String?
        let pAbId: String?
        let pAbId2: String?
    }

    private var currentAjaxCookies: AjaxCookieState {
        AjaxCookieState(
            phpSessId: currentAccount?.webPHPSESSID,
            yuidB: currentAccount?.webYuidB,
            pAbDId: currentAccount?.webPAbDId,
            pAbId: currentAccount?.webPAbId,
            pAbId2: currentAccount?.webPAbId2
        )
    }

    private let lastUserIdKey = "last_active_user_id"

    /// 标记用户已尝试过登录（用于游客模式判断）
    private(set) var hasAttemptedLogin: Bool = false

    /// 是否为游客模式（未登录但可以浏览公开内容）
    var isGuestMode: Bool {
        !isLoggedIn && hasAttemptedLogin
    }

    /// Web API 是否已经登录（包含有效的 PHPSESSID）
    var isWebLoggedIn: Bool {
        currentAccount?.webPHPSESSID?.contains("_") == true
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
            updateCurrentAccountFromAccounts()
            self.isLoaded = true
        } catch {
            self.error = AppError.databaseError("无法加载账户: \(error)")
            self.isLoaded = true
        }
    }

    func loadAccountsAsync() async {
        let backgroundContext = dataContainer.createBackgroundContext()
        do {
            let descriptor = FetchDescriptor<AccountPersist>()
            let fetched = try backgroundContext.fetch(descriptor)
            let ids = fetched.map { $0.persistentModelID }

            await MainActor.run {
                let mainContext = dataContainer.mainContext
                self.accounts = ids.compactMap { mainContext.model(for: $0) as? AccountPersist }
                updateCurrentAccountFromAccounts()
                self.isLoaded = true
            }
        } catch {
            await MainActor.run {
                self.error = AppError.databaseError("无法加载账户: \(error)")
                self.isLoaded = true
            }
        }
    }

    @MainActor
    private func updateCurrentAccountFromAccounts() {
        let lastUserId = UserDefaults.standard.string(forKey: lastUserIdKey)
        let accountToUse: AccountPersist?

        if let savedAccount = accounts.first(where: { $0.userId == lastUserId }) {
            accountToUse = savedAccount
        } else if let firstAccount = accounts.first {
            accountToUse = firstAccount
            UserDefaults.standard.set(firstAccount.userId, forKey: lastUserIdKey)
        } else {
            accountToUse = nil
        }

        if let account = accountToUse {
            self.currentAccount = account
            self.isLoggedIn = true

            // 从 Keychain 加载令牌
            loadTokensFromKeychain(for: account)

            // SwiftData 中仍有账户资料不代表凭证可用。令牌缺失时保留账户列表，
            // 但不要把应用标记为已登录，否则后续请求会以空令牌运行并表现为“自动掉线”。
            guard !account.refreshToken.isEmpty else {
                self.currentAccount = nil
                self.isLoggedIn = false
                Logger.auth.error("账户凭证缺失，需要重新登录: \(account.userId, privacy: .public)")
                PixivAPI.shared.setAccessToken("")
                PixivAPI.shared.setAjaxSessionCookies(phpSessId: nil, yuidB: nil, pAbDId: nil, pAbId: nil, pAbId2: nil)
                return
            }

            PixivAPI.shared.setAccessToken(account.accessToken)
            PixivAPI.shared.setAjaxSessionCookies(
                phpSessId: account.webPHPSESSID,
                yuidB: account.webYuidB,
                pAbDId: account.webPAbDId,
                pAbId: account.webPAbId,
                pAbId2: account.webPAbId2
            )
        } else {
            self.currentAccount = nil
            self.isLoggedIn = false
            PixivAPI.shared.setAjaxSessionCookies(phpSessId: nil, yuidB: nil, pAbDId: nil, pAbId: nil, pAbId2: nil)
        }
    }

    private func loadTokensFromKeychain(for account: AccountPersist) {
        let userId = account.userId
        do {
            if let accessToken = try KeychainHelper.load(service: KeychainHelper.Service.authTokens, account: KeychainHelper.accountKey(userId: userId, type: .accessToken)) {
                account.accessToken = accessToken
            }
            if let refreshToken = try KeychainHelper.load(service: KeychainHelper.Service.authTokens, account: KeychainHelper.accountKey(userId: userId, type: .refreshToken)) {
                account.refreshToken = refreshToken
            }
            if let phpsessid = try KeychainHelper.load(service: KeychainHelper.Service.authTokens, account: KeychainHelper.accountKey(userId: userId, type: .phpsessid)) {
                account.webPHPSESSID = phpsessid
            }
        } catch {
            Logger.auth.error("Failed to load tokens from keychain for \(userId, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    @discardableResult
    private func saveTokensToKeychain(for account: AccountPersist, expiresIn: Int = 3600) -> Bool {
        let userId = account.userId
        do {
            try KeychainHelper.save(account.accessToken, service: KeychainHelper.Service.authTokens, account: KeychainHelper.accountKey(userId: userId, type: .accessToken))
            try KeychainHelper.save(account.refreshToken, service: KeychainHelper.Service.authTokens, account: KeychainHelper.accountKey(userId: userId, type: .refreshToken))
            if let phpsessid = account.webPHPSESSID {
                try KeychainHelper.save(phpsessid, service: KeychainHelper.Service.authTokens, account: KeychainHelper.accountKey(userId: userId, type: .phpsessid))
            } else {
                try KeychainHelper.delete(service: KeychainHelper.Service.authTokens, account: KeychainHelper.accountKey(userId: userId, type: .phpsessid))
            }
            // 保存 token 过期时间（使用服务端返回的 expires_in）
            Logger.token.debug("服务端返回 expires_in=\(expiresIn)s (\(Double(expiresIn) / 60) 分钟)")
            let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
            Logger.token.debug("token 过期时间: \(ISO8601DateFormatter().string(from: expiryDate))")
            try KeychainHelper.save(
                ISO8601DateFormatter().string(from: expiryDate),
                service: KeychainHelper.Service.authTokens,
                account: KeychainHelper.accountKey(userId: userId, type: .tokenExpiry)
            )
            return true
        } catch {
            Logger.auth.error("Failed to save tokens to keychain for \(userId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func deleteTokensFromKeychain(userId: String) {
        do {
            try KeychainHelper.delete(service: KeychainHelper.Service.authTokens, account: KeychainHelper.accountKey(userId: userId, type: .accessToken))
            try KeychainHelper.delete(service: KeychainHelper.Service.authTokens, account: KeychainHelper.accountKey(userId: userId, type: .refreshToken))
            try KeychainHelper.delete(service: KeychainHelper.Service.authTokens, account: KeychainHelper.accountKey(userId: userId, type: .phpsessid))
            try KeychainHelper.delete(service: KeychainHelper.Service.authTokens, account: KeychainHelper.accountKey(userId: userId, type: .tokenExpiry))
        } catch {
            Logger.auth.error("Failed to delete tokens from keychain for \(userId, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 主动刷新缓冲时间，提前刷新避免边缘情况
    private static let tokenRefreshBuffer: TimeInterval = 300

    /// 标记用户已尝试过登录（启动时调用）
    func markLoginAttempted() {
        hasAttemptedLogin = true
    }

    /// 启动时检查 token 是否已过期，过期则主动刷新
    func refreshTokenIfExpired() async {
        guard let account = currentAccount, !account.refreshToken.isEmpty else { return }
        guard isTokenExpired() else {
            Logger.token.debug("token 仍有效，跳过主动刷新")
            return
        }

        Logger.token.debug("token 已过期，主动刷新...")

        do {
            let (newAccessToken, newRefreshToken, _, expiresIn) = try await PixivAPI.shared.refreshAccessToken(account.refreshToken)
            account.accessToken = newAccessToken
            account.refreshToken = newRefreshToken
            try updateAccount(account, expiresIn: expiresIn)
            PixivAPI.shared.setAccessToken(newAccessToken)
            Logger.token.info("主动刷新成功")
        } catch {
            // 静默失败 — NetworkClient 的失败重试兜底
            Logger.token.debug("主动刷新失败，后续请求将自动重试: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 判断存储的 token 是否已过期
    private func isTokenExpired() -> Bool {
        guard let account = currentAccount else { return true }
        let userId = account.userId
        guard let dateStr = try? KeychainHelper.load(
            service: KeychainHelper.Service.authTokens,
            account: KeychainHelper.accountKey(userId: userId, type: .tokenExpiry)
        ), let expiryDate = ISO8601DateFormatter().date(from: dateStr) else {
            // 无过期时间 → 按已过期处理
            return true
        }
        // 提前 buffer 时间刷新，避免边缘情况
        return Date() >= expiryDate.addingTimeInterval(-Self.tokenRefreshBuffer)
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
            let (accessToken, user, expiresIn) = try await PixivAPI.shared.loginWithRefreshToken(refreshToken)

            // 创建新账户
            let account = AccountPersist(
                user: user,
                accessToken: accessToken,
                refreshToken: refreshToken,
                deviceToken: ""
            )

            try await saveAccount(account, expiresIn: expiresIn)
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
            let (accessToken, refreshToken, user, expiresIn) = try await PixivAPI.shared.loginWithCode(code, codeVerifier: codeVerifier)

            // 创建新账户
            let account = AccountPersist(
                user: user,
                accessToken: accessToken,
                refreshToken: refreshToken,
                deviceToken: ""
            )

            try await saveAccount(account, expiresIn: expiresIn)
            isLoading = false
        } catch {
            self.error = AppError.networkError("登录失败: \(error.localizedDescription)")
            isLoading = false
        }
    }

    /// 保存新账户
    func saveAccount(_ account: AccountPersist, expiresIn: Int = 3600) async throws {
        let context = dataContainer.mainContext
        let targetUserId = account.userId

        // 保存到 Keychain
        guard saveTokensToKeychain(for: account, expiresIn: expiresIn) else {
            throw AppError.databaseError("无法将登录凭证保存到钥匙串，请检查系统钥匙串权限后重试")
        }

        // 检查是否已存在
        let descriptor = FetchDescriptor<AccountPersist>(
            predicate: #Predicate { $0.userId == targetUserId }
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
            if let webPHPSESSID = account.webPHPSESSID {
                existing.webPHPSESSID = webPHPSESSID
            }
        } else {
            // 添加新账户
            context.insert(account)
        }

        try context.save()
        UserDefaults.standard.set(account.userId, forKey: lastUserIdKey)

        // 重新加载账户列表
        loadAccounts()

        // 设置为重新加载后的托管对象，避免继续持有刚创建的非托管对象。
        self.currentAccount = accounts.first(where: { $0.userId == targetUserId }) ?? account
        self.isLoggedIn = true

        // 清理缓存并重新加载数据
        await onAccountChanged()
    }

    /// 删除账户
    func deleteAccount(_ account: AccountPersist) throws {
        let context = dataContainer.mainContext
        let targetUserId = account.userId

        let descriptor = FetchDescriptor<AccountPersist>(
            predicate: #Predicate { $0.userId == targetUserId }
        )
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }

        // 从 Keychain 删除
        deleteTokensFromKeychain(userId: targetUserId)

        loadAccounts()
    }

    /// 更新账户信息
    func updateAccount(_ account: AccountPersist, expiresIn: Int = 3600) throws {
        let context = dataContainer.mainContext
        let targetUserId = account.userId

        let descriptor = FetchDescriptor<AccountPersist>(
            predicate: #Predicate { $0.userId == targetUserId }
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
            // 同步保存到 Keychain，确保下次启动时加载的是最新 token
            guard saveTokensToKeychain(for: existing, expiresIn: expiresIn) else {
                throw AppError.databaseError("无法更新钥匙串中的登录凭证")
            }
        }
    }

    /// 切换当前账户
    func switchAccount(_ account: AccountPersist) async {
        self.currentAccount = account
        self.isLoggedIn = true
        PixivAPI.shared.setAccessToken(account.accessToken)
        PixivAPI.shared.setAjaxSessionCookies(
            phpSessId: account.webPHPSESSID,
            yuidB: account.webYuidB,
            pAbDId: account.webPAbDId,
            pAbId: account.webPAbId,
            pAbId2: account.webPAbId2
        )
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
                PixivAPI.shared.setAjaxSessionCookies(phpSessId: nil, yuidB: nil, pAbDId: nil, pAbId: nil, pAbId2: nil)
            }
        }

        await onAccountChanged()
    }

    /// 当账号变动（切换、登入、登出）时调用
    private func onAccountChanged() async {
        // 1. 清理内存缓存
        CacheManager.shared.clearAll()

        // 2. 通知各 Store 清理内存状态并重新加载数据
        NotificationCenter.default.post(name: .accountDidChange, object: nil)

        // 3. 重置导航或其他全局状态
        self.navigationRequest = nil
    }

    /// 更新当前账号的 Ajax Web 会话（PHPSESSID）
    func updateCurrentAccountPHPSESSID(_ phpsessid: String?) {
        updateCurrentAccountAjaxCookies(
            phpSessId: phpsessid,
            yuidB: currentAjaxCookies.yuidB,
            pAbDId: currentAjaxCookies.pAbDId,
            pAbId: currentAjaxCookies.pAbId,
            pAbId2: currentAjaxCookies.pAbId2
        )
    }

    /// 更新当前账号的 Ajax Web 会话 cookies
    func updateCurrentAccountAjaxCookies(
        phpSessId: String?,
        yuidB: String?,
        pAbDId: String?,
        pAbId: String?,
        pAbId2: String?
    ) {
        guard let current = currentAccount else { return }

        current.webPHPSESSID = normalizeCookieValue(phpSessId)
        current.webYuidB = normalizeCookieValue(yuidB)
        current.webPAbDId = normalizeCookieValue(pAbDId)
        current.webPAbId = normalizeCookieValue(pAbId)
        current.webPAbId2 = normalizeCookieValue(pAbId2)

        do {
            try dataContainer.save()
        } catch {
            self.error = AppError.databaseError("无法保存 Ajax 会话: \(error)")
        }

        // 同步保存 PHPSESSID 到 Keychain，确保下次启动时能恢复
        do {
            if let sessionId = current.webPHPSESSID {
                try KeychainHelper.save(
                    sessionId,
                    service: KeychainHelper.Service.authTokens,
                    account: KeychainHelper.accountKey(userId: current.userId, type: .phpsessid)
                )
            } else {
                try KeychainHelper.delete(
                    service: KeychainHelper.Service.authTokens,
                    account: KeychainHelper.accountKey(userId: current.userId, type: .phpsessid)
                )
            }
        } catch {
            Logger.auth.error("Failed to save Web API session to keychain for \(current.userId, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        PixivAPI.shared.setAjaxSessionCookies(
            phpSessId: current.webPHPSESSID,
            yuidB: current.webYuidB,
            pAbDId: current.webPAbDId,
            pAbId: current.webPAbId,
            pAbId2: current.webPAbId2
        )
    }

    /// 清除当前账号的 Ajax Web 会话
    func clearCurrentAccountPHPSESSID() {
        updateCurrentAccountAjaxCookies(
            phpSessId: nil,
            yuidB: nil,
            pAbDId: nil,
            pAbId: nil,
            pAbId2: nil
        )
    }

    private func normalizeCookieValue(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalized, !normalized.isEmpty {
            return normalized
        }
        return nil
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
            let (accessToken, refreshToken, user, expiresIn) = try await PixivAPI.shared.refreshAccessToken(account.refreshToken)

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

            try updateAccount(account, expiresIn: expiresIn)
        } catch {
            Logger.auth.error("刷新账户信息失败: \(error.localizedDescription, privacy: .public)")
        }
    }
}

import Foundation
import Observation

@MainActor
@Observable
final class WebDAVSyncStore {
    static let shared = WebDAVSyncStore()

    var serverURLString = ""
    var username = ""
    var remoteDirectory = "Pixiv-SwiftUI"
    var password = ""

    var isBusy = false
    var busyMessage = ""
    var statusMessage = ""
    var error: AppError?
    var showError: Bool { error != nil }
    var successMessage = ""
    var showSuccessToast = false
    var lastOperationDescription = "从未同步"

    @ObservationIgnored
    private let service = WebDAVSyncService.shared
    private let authSession: AuthSessionProtocol

    private init(
        authSession: AuthSessionProtocol = AccountStore.shared
    ) {
        self.authSession = authSession
        reloadConfiguration()
        NotificationCenter.default.addObserver(
            forName: .accountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.invalidateForAccountChange()
            }
        }
    }

    var accountScopeDescription: String {
        let basePath = remoteDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        if basePath.isEmpty {
            return authSession.currentUserId
        }
        return basePath + "/" + authSession.currentUserId
    }

    var hasConfiguration: Bool {
        !serverURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !password.isEmpty
    }

    func reloadConfiguration() {
        let configuration = WebDAVSyncPreferences.loadConfiguration()
        serverURLString = configuration.serverURLString
        username = configuration.username
        remoteDirectory = configuration.remoteDirectory
        password = (try? WebDAVSyncPreferences.loadPassword()) ?? ""
        updateLastOperationDescription()
    }

    func saveConfiguration() {
        do {
            let configuration = WebDAVSyncConfiguration(
                serverURLString: serverURLString,
                username: username,
                remoteDirectory: remoteDirectory
            )
            try WebDAVSyncPreferences.saveConfiguration(configuration)
            try WebDAVSyncPreferences.savePassword(password)
            statusMessage = "已保存 WebDAV 配置"
            showSuccess(message: statusMessage)
        } catch {
            present(error)
        }
    }

    func testConnection() async {
        let generation = authSession.accountGeneration
        let ownerId = authSession.currentUserId
        await perform("正在测试连接…", generation: generation, ownerId: ownerId) {
            let credentials = try persistAndBuildCredentials()
            let items = try await service.testConnection(
                using: credentials,
                ownerId: ownerId,
                accountGeneration: generation
            )
            if items.isEmpty {
                statusMessage = "连接成功，远端目录已准备好"
            } else {
                statusMessage = "连接成功，远端已有 \(items.count) 个备份文件"
            }
            showSuccess(message: statusMessage)
        }
    }

    func uploadBackup() async {
        let generation = authSession.accountGeneration
        let ownerId = authSession.currentUserId
        await perform("正在上传备份…", generation: generation, ownerId: ownerId) {
            let credentials = try persistAndBuildCredentials()
            let manifest = try await service.uploadBackup(
                using: credentials,
                ownerId: ownerId,
                accountGeneration: generation
            )
            statusMessage = "已上传 \(manifest.datasets.count) 份同步数据"
            updateLastOperationDescription()
            showSuccess(message: statusMessage)
        }
    }

    func restoreBackup() async {
        let generation = authSession.accountGeneration
        let ownerId = authSession.currentUserId
        await perform("正在恢复远端数据…", generation: generation, ownerId: ownerId) {
            let credentials = try persistAndBuildCredentials()
            let manifest = try await service.restoreBackup(
                using: credentials,
                ownerId: ownerId,
                accountGeneration: generation
            )
            statusMessage = "已从远端恢复 \(manifest.datasets.count) 份同步数据"
            updateLastOperationDescription()
            showSuccess(message: statusMessage)
        }
    }

    private func perform(
        _ message: String,
        generation: UInt,
        ownerId: String,
        action: () async throws -> Void
    ) async {
        guard isCurrentOperation(generation: generation, ownerId: ownerId) else { return }
        guard !isBusy else { return }
        isBusy = true
        busyMessage = message
        defer {
            isBusy = false
            busyMessage = ""
        }

        do {
            try await action()
        } catch {
            guard isCurrentOperation(generation: generation, ownerId: ownerId) else { return }
            present(error)
        }
    }

    private func invalidateForAccountChange() {
        error = nil
        statusMessage = ""
        successMessage = ""
        showSuccessToast = false
    }

    private func isCurrentOperation(generation: UInt, ownerId: String) -> Bool {
        authSession.isCurrentAccount(generation: generation, userId: ownerId)
    }

    private func persistAndBuildCredentials() throws -> WebDAVSyncCredentials {
        let configuration = WebDAVSyncConfiguration(
            serverURLString: serverURLString,
            username: username,
            remoteDirectory: remoteDirectory
        )
        let credentials = try configuration.makeCredentials(password: password)
        try WebDAVSyncPreferences.saveConfiguration(configuration)
        try WebDAVSyncPreferences.savePassword(password)
        return credentials
    }

    private func updateLastOperationDescription() {
        if let operation = WebDAVSyncPreferences.loadLastOperation(ownerId: authSession.currentUserId) {
            let operationText = switch operation.kind {
            case .upload:
                "最近一次上传"
            case .restore:
                "最近一次恢复"
            }
            lastOperationDescription = operationText + "：" + operation.date.formatted(date: .abbreviated, time: .shortened)
        } else {
            lastOperationDescription = "从未同步"
        }
    }

    private func present(_ error: Error) {
        self.error = AppError.unknown(error)
    }

    private func showSuccess(message: String) {
        successMessage = message
        showSuccessToast = true
    }
}

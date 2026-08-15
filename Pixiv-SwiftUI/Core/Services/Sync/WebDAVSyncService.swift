import Foundation
import SwiftData

@MainActor
final class WebDAVSyncService {
    static let shared = WebDAVSyncService()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let dataContainer = DataContainer.shared
    private let userSettingStore = UserSettingStore.shared
    private let searchStore = SearchStore.shared

    private init() {}

    func testConnection(
        using credentials: WebDAVSyncCredentials,
        ownerId: String,
        accountGeneration: UInt
    ) async throws -> [WebDAVRemoteItem] {
        try ensureCurrentAccount(ownerId: ownerId, accountGeneration: accountGeneration)
        let client = WebDAVClient(credentials: credentials)
        let items = try await client.testConnection(ownerId: ownerId)
        try ensureCurrentAccount(ownerId: ownerId, accountGeneration: accountGeneration)
        return items
    }

    func uploadBackup(
        using credentials: WebDAVSyncCredentials,
        ownerId: String,
        accountGeneration: UInt
    ) async throws -> WebDAVSyncManifest {
        try ensureCurrentAccount(ownerId: ownerId, accountGeneration: accountGeneration)
        let client = WebDAVClient(credentials: credentials)
        let package = try buildUploadPackage(ownerId: ownerId)

        for (fileName, data) in package.files {
            try ensureCurrentAccount(ownerId: ownerId, accountGeneration: accountGeneration)
            try await client.upload(data, fileName: fileName, ownerId: ownerId)
        }

        try ensureCurrentAccount(ownerId: ownerId, accountGeneration: accountGeneration)
        try WebDAVSyncPreferences.saveLastOperation(
            WebDAVSyncOperationRecord(kind: .upload, date: package.manifest.exportedAt),
            ownerId: ownerId
        )
        return package.manifest
    }

    func restoreBackup(
        using credentials: WebDAVSyncCredentials,
        ownerId: String,
        accountGeneration: UInt
    ) async throws -> WebDAVSyncManifest {
        try ensureCurrentAccount(ownerId: ownerId, accountGeneration: accountGeneration)
        let client = WebDAVClient(credentials: credentials)
        let items = try await client.listItems(ownerId: ownerId)
        let fileNames = Set(items.filter { !$0.isDirectory }.map(\.fileName))

        guard fileNames.contains("manifest.json") else {
            throw WebDAVSyncError.remoteFileNotFound("manifest.json")
        }

        let manifestData = try await client.download(fileName: "manifest.json", ownerId: ownerId)
        let manifest = try decodeManifest(from: manifestData)

        if manifest.version != 1 {
            throw WebDAVSyncError.invalidManifest
        }

        for item in manifest.datasets {
            guard fileNames.contains(item.fileName) else {
                throw WebDAVSyncError.remoteFileNotFound(item.fileName)
            }

            let fileData = try await client.download(fileName: item.fileName, ownerId: ownerId)
            let digest = WebDAVSyncHashing.sha256Hex(for: fileData)
            guard digest == item.sha256 else {
                throw WebDAVSyncError.payloadIntegrityMismatch(item.fileName)
            }

            try ensureCurrentAccount(ownerId: ownerId, accountGeneration: accountGeneration)
            try applyDataset(item.dataset, data: fileData, ownerId: ownerId)
        }

        try ensureCurrentAccount(ownerId: ownerId, accountGeneration: accountGeneration)
        try WebDAVSyncPreferences.saveLastOperation(
            WebDAVSyncOperationRecord(kind: .restore, date: Date()),
            ownerId: ownerId
        )
        return manifest
    }

    private func ensureCurrentAccount(ownerId: String, accountGeneration: UInt) throws {
        guard AccountStore.shared.isCurrentAccount(generation: accountGeneration, userId: ownerId) else {
            throw WebDAVSyncError.accountChanged
        }
    }

    private func buildUploadPackage(ownerId: String) throws -> (manifest: WebDAVSyncManifest, files: [(String, Data)]) {
        let settingsPayload = WebDAVSyncSafeSettingsPayload(setting: userSettingStore.userSetting)
        let mutePayload = WebDAVSyncMutePayload(
            blockedTags: userSettingStore.blockedTags,
            blockedUsers: userSettingStore.blockedUsers,
            blockedIllusts: userSettingStore.blockedIllusts,
            blockedNovels: userSettingStore.blockedNovels,
            blockedNovelTitleKeywords: userSettingStore.blockedNovelTitleKeywords,
            blockedNovelSeriesKeywords: userSettingStore.blockedNovelSeriesKeywords,
            blockedNovelCaptionKeywords: userSettingStore.blockedNovelCaptionKeywords,
            blockedTagInfos: userSettingStore.blockedTagInfos.map(WebDAVBlockedTagInfoPayload.init),
            blockedUserInfos: userSettingStore.blockedUserInfos.map(WebDAVBlockedUserInfoPayload.init),
            blockedIllustInfos: userSettingStore.blockedIllustInfos.map(WebDAVBlockedIllustInfoPayload.init),
            blockedNovelInfos: userSettingStore.blockedNovelInfos.map(WebDAVBlockedNovelInfoPayload.init)
        )
        let searchHistoryPayload = WebDAVSyncSearchHistoryPayload(tags: Array(searchStore.searchHistory.prefix(100)))
        let novelReaderPayload = buildNovelReaderPayload()

        let datasetData: [(WebDAVSyncDataset, Data)] = [
            (.safeSettings, try encoder.encode(settingsPayload)),
            (.muteData, try encoder.encode(mutePayload)),
            (.searchHistory, try encoder.encode(searchHistoryPayload)),
            (.novelReader, try encoder.encode(novelReaderPayload)),
        ]

        let manifestItems = datasetData.map { dataset, data in
            WebDAVSyncManifestItem(
                dataset: dataset,
                fileName: dataset.fileName,
                sha256: WebDAVSyncHashing.sha256Hex(for: data),
                byteCount: data.count
            )
        }

        let manifest = WebDAVSyncManifest(
            version: 1,
            ownerId: ownerId,
            exportedAt: Date(),
            appVersion: appVersion,
            datasets: manifestItems
        )
        let manifestData = try encoder.encode(manifest)

        let files = datasetData.map { ($0.0.fileName, $0.1) } + [("manifest.json", manifestData)]
        return (manifest, files)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }

    private func decodeManifest(from data: Data) throws -> WebDAVSyncManifest {
        do {
            return try decoder.decode(WebDAVSyncManifest.self, from: data)
        } catch {
            throw WebDAVSyncError.invalidManifest
        }
    }

    private func applyDataset(_ dataset: WebDAVSyncDataset, data: Data, ownerId: String) throws {
        switch dataset {
        case .safeSettings:
            let payload = try decoder.decode(WebDAVSyncSafeSettingsPayload.self, from: data)
            try applySettings(payload)
        case .muteData:
            let payload = try decoder.decode(WebDAVSyncMutePayload.self, from: data)
            try applyMuteData(payload, ownerId: ownerId)
        case .searchHistory:
            let payload = try decoder.decode(WebDAVSyncSearchHistoryPayload.self, from: data)
            applySearchHistory(payload)
        case .novelReader:
            let payload = try decoder.decode(WebDAVSyncNovelReaderPayload.self, from: data)
            applyNovelReader(payload)
        }
    }

    private func applySettings(_ payload: WebDAVSyncSafeSettingsPayload) throws {
        let setting = userSettingStore.userSetting
        setting.pictureQuality = payload.pictureQuality
        setting.mangaQuality = payload.mangaQuality
        setting.feedPreviewQuality = payload.feedPreviewQuality
        setting.zoomQuality = payload.zoomQuality
        setting.languageNum = payload.languageNum
        setting.crossCount = payload.crossCount
        setting.hCrossCount = payload.hCrossCount
        setting.crossAdaptWidth = payload.crossAdaptWidth
        setting.crossAdapt = payload.crossAdapt
        setting.hCrossAdaptWidth = payload.hCrossAdaptWidth
        setting.hCrossAdapt = payload.hCrossAdapt
        setting.colorSchemeMode = payload.colorSchemeMode
        setting.isTopMode = payload.isTopMode
        setting.novelFontSize = payload.novelFontSize
        setting.seedColor = payload.seedColor
        setting.isCustomTheme = payload.isCustomTheme
        setting.customThemeColor = payload.customThemeColor
        setting.aiDisplayMode = payload.aiDisplayMode
        setting.r18DisplayMode = payload.r18DisplayMode
        setting.r18gDisplayMode = payload.r18gDisplayMode
        setting.showXVIIIRankingGroups = payload.showXVIIIRankingGroups ?? false
        if let enabledHiddenIllustRankingModes = payload.enabledHiddenIllustRankingModes {
            setting.enabledHiddenIllustRankingModes = enabledHiddenIllustRankingModes
            setting.showXVIIIRankingGroups = enabledHiddenIllustRankingModes.contains { value in
                IllustRankingMode.xviiiModes.contains { $0.rawValue == value }
            }
        } else if setting.showXVIIIRankingGroups {
            setting.enabledHiddenIllustRankingModes = IllustRankingMode.xviiiModes.map(\.rawValue)
        } else {
            setting.enabledHiddenIllustRankingModes = []
        }
        let enabledRankingModes = IllustRankingMode.enabledModes(
            from: payload.enabledIllustRankingModes ?? [],
            legacyHiddenRawValues: setting.enabledHiddenIllustRankingModes,
            showXVIIIRankingGroups: setting.showXVIIIRankingGroups
        )
        setting.enabledIllustRankingModes = enabledRankingModes.map(\.rawValue)
        setting.enabledHiddenIllustRankingModes = IllustRankingMode.enabledHiddenModes(from: enabledRankingModes).map(\.rawValue)
        setting.showXVIIIRankingGroups = enabledRankingModes.contains { $0.isXVIIIMode }
        setting.illustRankingModeOrder = payload.illustRankingModeOrder
            ?? IllustRankingMode.allModes.map(\.rawValue)
        setting.spoilerDisplayMode = payload.spoilerDisplayMode
        setting.blurAppPreviewInBackground = payload.blurAppPreviewInBackground ?? false
        setting.autoPlayUgoira = payload.autoPlayUgoira
        setting.showGifAvatar = payload.showGifAvatar
        setting.copyInfoText = payload.copyInfoText
        setting.animContainer = payload.animContainer
        setting.translateServiceId = payload.translateServiceId
        setting.translateTargetLanguage = payload.translateTargetLanguage
        setting.translatePrimaryServiceId = payload.translatePrimaryServiceId
        setting.translateTapToTranslate = payload.translateTapToTranslate
        setting.translateNovelBatchEnabled = payload.translateNovelBatchEnabled
        setting.translateNovelBatchMaxParagraphs = payload.translateNovelBatchMaxParagraphs
        setting.translateNovelBatchMaxCharacters = payload.translateNovelBatchMaxCharacters
        setting.translateNovelContextParagraphs = payload.translateNovelContextParagraphs
        setting.translateNovelMaxConcurrentBatches = payload.translateNovelMaxConcurrentBatches
        setting.vlmEnabled = payload.vlmEnabled
        setting.vlmModel = payload.vlmModel
        setting.vlmTemperature = payload.vlmTemperature
        setting.vlmDetail = payload.vlmDetail
        setting.tagTranslationDisplayMode = payload.tagTranslationDisplayMode
        setting.defaultTab = payload.defaultTab
        setting.checkUpdateOnLaunch = payload.checkUpdateOnLaunch

        try userSettingStore.saveSetting()
        ThemeManager.shared.applyThemeMode()
    }

    private func applyMuteData(_ payload: WebDAVSyncMutePayload, ownerId: String) throws {
        let setting = userSettingStore.userSetting

        let blockedTagInfos = payload.blockedTagInfos.map {
            BlockedTagInfo(name: $0.name, translatedName: $0.translatedName)
        }
        let blockedUserInfos = payload.blockedUserInfos.map {
            BlockedUserInfo(userId: $0.userId, name: $0.name, account: $0.account, avatarUrl: $0.avatarUrl)
        }
        let blockedIllustInfos = payload.blockedIllustInfos.map {
            BlockedIllustInfo(
                illustId: $0.illustId,
                title: $0.title,
                authorId: $0.authorId,
                authorName: $0.authorName,
                thumbnailUrl: $0.thumbnailUrl
            )
        }
        let blockedNovelInfos = payload.blockedNovelInfos.map {
            BlockedNovelInfo(
                novelId: $0.novelId,
                title: $0.title,
                authorId: $0.authorId,
                authorName: $0.authorName,
                thumbnailUrl: $0.thumbnailUrl
            )
        }

        userSettingStore.blockedTags = payload.blockedTags
        userSettingStore.blockedUsers = payload.blockedUsers
        userSettingStore.blockedIllusts = payload.blockedIllusts
        userSettingStore.blockedNovels = payload.blockedNovels
        userSettingStore.blockedNovelTitleKeywords = payload.blockedNovelTitleKeywords
        userSettingStore.blockedNovelSeriesKeywords = payload.blockedNovelSeriesKeywords
        userSettingStore.blockedNovelCaptionKeywords = payload.blockedNovelCaptionKeywords
        userSettingStore.blockedTagInfos = blockedTagInfos
        userSettingStore.blockedUserInfos = blockedUserInfos
        userSettingStore.blockedIllustInfos = blockedIllustInfos
        userSettingStore.blockedNovelInfos = blockedNovelInfos

        setting.blockedTags = payload.blockedTags
        setting.blockedUsers = payload.blockedUsers
        setting.blockedIllusts = payload.blockedIllusts
        setting.blockedNovels = payload.blockedNovels
        setting.blockedNovelTitleKeywords = payload.blockedNovelTitleKeywords
        setting.blockedNovelSeriesKeywords = payload.blockedNovelSeriesKeywords
        setting.blockedNovelCaptionKeywords = payload.blockedNovelCaptionKeywords
        setting.blockedTagInfos = blockedTagInfos
        setting.blockedUserInfos = blockedUserInfos
        setting.blockedIllustInfos = blockedIllustInfos
        setting.blockedNovelInfos = blockedNovelInfos

        let context = dataContainer.mainContext
        try context.delete(model: BanTag.self, where: #Predicate { $0.ownerId == ownerId })
        try context.delete(model: BanUserId.self, where: #Predicate { $0.ownerId == ownerId })
        try context.delete(model: BanIllustId.self, where: #Predicate { $0.ownerId == ownerId })

        for tag in payload.blockedTags {
            context.insert(BanTag(name: tag, ownerId: ownerId))
        }

        for userId in payload.blockedUsers {
            context.insert(BanUserId(userId: userId, ownerId: ownerId))
        }

        for illustId in payload.blockedIllusts {
            context.insert(BanIllustId(illustId: illustId, ownerId: ownerId))
        }

        try userSettingStore.saveSetting()
    }

    private func buildNovelReaderPayload() -> WebDAVSyncNovelReaderPayload {
        let defaults = UserDefaults.standard
        let progresses = defaults.dictionaryRepresentation()
            .compactMap { key, value -> WebDAVNovelReaderProgressPayload? in
                guard key.hasPrefix("novel_reader_progress_") else {
                    return nil
                }

                let suffix = key.replacingOccurrences(of: "novel_reader_progress_", with: "")
                guard let novelId = Int(suffix) else {
                    return nil
                }

                if let progress = value as? [String: Int] {
                    return WebDAVNovelReaderProgressPayload(
                        novelId: novelId,
                        index: progress["index"] ?? 0,
                        totalSpans: progress["total"]
                    )
                }

                if let index = value as? Int {
                    return WebDAVNovelReaderProgressPayload(novelId: novelId, index: index, totalSpans: nil)
                }

                return nil
            }
            .sorted { $0.novelId < $1.novelId }

        let settings: NovelReaderSettings?
        if let data = defaults.data(forKey: "novel_reader_settings") {
            settings = try? decoder.decode(NovelReaderSettings.self, from: data)
        } else {
            settings = nil
        }

        return WebDAVSyncNovelReaderPayload(settings: settings, progresses: progresses)
    }

    private func applySearchHistory(_ payload: WebDAVSyncSearchHistoryPayload) {
        searchStore.searchHistory = Array(payload.tags.prefix(100))
        searchStore.saveSearchHistory()
    }

    private func applyNovelReader(_ payload: WebDAVSyncNovelReaderPayload) {
        let defaults = UserDefaults.standard
        let keysToRemove = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("novel_reader_progress_") }
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }

        for progress in payload.progresses {
            let key = "novel_reader_progress_\(progress.novelId)"
            var value: [String: Int] = ["index": progress.index]
            if let totalSpans = progress.totalSpans {
                value["total"] = totalSpans
            }
            defaults.set(value, forKey: key)
        }

        if let settings = payload.settings, let data = try? encoder.encode(settings) {
            defaults.set(data, forKey: "novel_reader_settings")
        }
    }
}

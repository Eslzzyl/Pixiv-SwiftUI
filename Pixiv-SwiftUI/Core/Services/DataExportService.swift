import Foundation
import SwiftData
import SwiftUI
import Combine

enum DataExportError: LocalizedError {
    case invalidFormat
    case parseError(String)
    case fileOperationFailed(String)
    case noData
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "无效的数据格式"
        case .parseError(let msg):
            return "解析失败: \(msg)"
        case .fileOperationFailed(let msg):
            return "文件操作失败: \(msg)"
        case .noData:
            return "没有可导出的数据"
        case .cancelled:
            return "操作已取消"
        }
    }
}

@MainActor
final class DataExportService {
    static let shared = DataExportService()

    private let dataContainer = DataContainer.shared
    private let illustStore = IllustStore.shared
    private let novelStore = NovelStore.shared
    private let userSettingStore = UserSettingStore.shared
    private let searchStore = SearchStore()

    private var currentUserId: String {
        AccountStore.shared.currentUserId
    }

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

    private init() {}

    func exportSearchHistory() async throws -> URL {
        let tags = searchStore.searchHistory.map { tag -> TagHistoryItem in
            TagHistoryItem(
                name: tag.name,
                translatedName: tag.translatedName,
                type: tag.type
            )
        }

        let export = SearchHistoryExport(tagHistory: tags, bookTags: [])
        let header = ExportHeader(version: 1, type: .searchHistory, exportedAt: Date())

        let wrapped = SearchHistoryWrapper(header: header, data: export)
        let jsonData = try encoder.encode(wrapped)
        let fileName = "pixiv_search_history_\(Date().ISO8601Format()).json"

        return try saveToTemporaryFile(data: jsonData, fileName: fileName)
    }

    func exportGlanceHistory() async throws -> URL {
        let illustHistory = try illustStore.getGlanceHistory(limit: 200)
        let novelHistory = try novelStore.getGlanceHistory(limit: 200)

        let illustItems = illustHistory.map { item -> IllustHistoryItem in
            let cached = (try? illustStore.getCachedIllusts([item.illustId]))?.first
            return IllustHistoryItem(
                illustId: item.illustId,
                viewedAt: Int64(item.viewedAt.timeIntervalSince1970 * 1000),
                title: cached?.title,
                userName: cached?.user.name
            )
        }

        let novelItems = novelHistory.map { item -> NovelHistoryItem in
            NovelHistoryItem(
                novelId: item.novelId,
                viewedAt: Int64(item.viewedAt.timeIntervalSince1970 * 1000),
                title: nil,
                userName: nil
            )
        }

        let export = GlanceHistoryExport(illustHistory: illustItems, novelHistory: novelItems)
        let header = ExportHeader(version: 1, type: .glanceHistory, exportedAt: Date())

        let wrapped = GlanceHistoryWrapper(header: header, data: export)
        let jsonData = try encoder.encode(wrapped)
        let fileName = "pixiv_glance_history_\(Date().ISO8601Format()).json"

        return try saveToTemporaryFile(data: jsonData, fileName: fileName)
    }

    func exportMuteData() async throws -> URL {
        let context = dataContainer.mainContext

        let banTagDescriptor = FetchDescriptor<BanTag>(
            predicate: #Predicate { $0.ownerId == currentUserId }
        )
        let banTags = try context.fetch(banTagDescriptor)

        let banUserDescriptor = FetchDescriptor<BanUserId>(
            predicate: #Predicate { $0.ownerId == currentUserId }
        )
        let banUsers = try context.fetch(banUserDescriptor)

        let banIllustDescriptor = FetchDescriptor<BanIllustId>(
            predicate: #Predicate { $0.ownerId == currentUserId }
        )
        let banIllusts = try context.fetch(banIllustDescriptor)

        let banTagItems = banTags.map { BanTagItem(name: $0.name, translatedName: nil) }
        let banUserItems = banUsers.map { BanUserIdItem(userId: $0.userId, name: nil) }
        let banIllustItems = banIllusts.map { BanIllustIdItem(illustId: $0.illustId, name: nil) }

        let export = MuteDataExport(
            banTags: banTagItems,
            banUserIds: banUserItems,
            banIllustIds: banIllustItems
        )
        let header = ExportHeader(version: 1, type: .muteData, exportedAt: Date())

        let wrapped = MuteDataWrapper(header: header, data: export)
        let jsonData = try encoder.encode(wrapped)
        let fileName = "pixiv_mute_data_\(Date().ISO8601Format()).json"

        return try saveToTemporaryFile(data: jsonData, fileName: fileName)
    }

    private func saveToTemporaryFile(data: Data, fileName: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            throw DataExportError.fileOperationFailed(error.localizedDescription)
        }
    }

    func importSearchHistory(from url: URL, strategy: ImportConflictStrategy) async throws {
        let jsonData = try Data(contentsOf: url)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        guard let json = jsonObject else {
            throw DataExportError.invalidFormat
        }

        let format = FlutterCompat.detectFormat(from: json)
        let exportData: SearchHistoryExport

        switch format {
        case .swiftuiExport:
            let wrapper = try decoder.decode(SearchHistoryWrapper.self, from: jsonData)
            exportData = wrapper.data
        case .flutterSearchHistory:
            guard let parsed = FlutterCompat.parseFlutterSearchHistory(from: json) else {
                throw DataExportError.parseError("无法解析搜索历史数据")
            }
            exportData = parsed
        default:
            throw DataExportError.invalidFormat
        }

        switch strategy {
        case .merge:
            try mergeSearchHistory(imported: exportData.tagHistory)
        case .replace:
            try replaceSearchHistory(imported: exportData.tagHistory)
        case .cancel:
            throw DataExportError.cancelled
        }
    }

    func importGlanceHistory(from url: URL, strategy: ImportConflictStrategy) async throws {
        let jsonData = try Data(contentsOf: url)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        guard let json = jsonObject else {
            throw DataExportError.invalidFormat
        }

        let format = FlutterCompat.detectFormat(from: json)
        let exportData: GlanceHistoryExport

        switch format {
        case .swiftuiExport:
            let wrapper = try decoder.decode(GlanceHistoryWrapper.self, from: jsonData)
            exportData = wrapper.data
        case .flutterGlanceHistory:
            guard let parsed = FlutterCompat.parseFlutterGlanceHistory(from: json) else {
                throw DataExportError.parseError("无法解析浏览历史数据")
            }
            exportData = parsed
        default:
            throw DataExportError.invalidFormat
        }

        switch strategy {
        case .merge:
            try mergeGlanceHistory(illustItems: exportData.illustHistory, novelItems: exportData.novelHistory)
        case .replace:
            try replaceGlanceHistory(illustItems: exportData.illustHistory, novelItems: exportData.novelHistory)
        case .cancel:
            throw DataExportError.cancelled
        }
    }

    func importMuteData(from url: URL, strategy: ImportConflictStrategy) async throws {
        let jsonData = try Data(contentsOf: url)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        guard let json = jsonObject else {
            throw DataExportError.invalidFormat
        }

        let format = FlutterCompat.detectFormat(from: json)
        let exportData: MuteDataExport

        switch format {
        case .swiftuiExport:
            let wrapper = try decoder.decode(MuteDataWrapper.self, from: jsonData)
            exportData = wrapper.data
        case .flutterMuteData:
            guard let parsed = FlutterCompat.parseFlutterMuteData(from: json) else {
                throw DataExportError.parseError("无法解析屏蔽数据")
            }
            exportData = parsed
        default:
            throw DataExportError.invalidFormat
        }

        switch strategy {
        case .merge:
            try mergeMuteData(banTags: exportData.banTags, banUsers: exportData.banUserIds, banIllusts: exportData.banIllustIds)
        case .replace:
            try replaceMuteData(banTags: exportData.banTags, banUsers: exportData.banUserIds, banIllusts: exportData.banIllustIds)
        case .cancel:
            throw DataExportError.cancelled
        }
    }

    private func mergeSearchHistory(imported: [TagHistoryItem]) throws {
        let existingNames = Set(searchStore.searchHistory.map { $0.name })

        for tag in imported where !existingNames.contains(tag.name) {
            let searchTag = SearchTag(
                name: tag.name,
                translatedName: tag.translatedName,
                type: tag.type
            )
            searchStore.addHistory(searchTag)
        }
    }

    private func replaceSearchHistory(imported: [TagHistoryItem]) throws {
        var newHistory: [SearchTag] = []
        for tag in imported {
            let searchTag = SearchTag(
                name: tag.name,
                translatedName: tag.translatedName,
                type: tag.type
            )
            newHistory.append(searchTag)
        }
        searchStore.searchHistory = newHistory
        searchStore.saveSearchHistory()
    }

    private func mergeGlanceHistory(illustItems: [IllustHistoryItem], novelItems: [NovelHistoryItem]) throws {
        let context = dataContainer.mainContext
        let uid = currentUserId

        for item in illustItems {
            let descriptor = FetchDescriptor<GlanceIllustPersist>(
                predicate: #Predicate { $0.illustId == item.illustId && $0.ownerId == uid }
            )
            if try context.fetch(descriptor).isEmpty {
                let viewedAt = Date(timeIntervalSince1970: Double(item.viewedAt) / 1000.0)
                let glance = GlanceIllustPersist(illustId: item.illustId, ownerId: uid)
                glance.viewedAt = viewedAt
                context.insert(glance)
            }
        }

        for item in novelItems {
            let descriptor = FetchDescriptor<GlanceNovelPersist>(
                predicate: #Predicate { $0.novelId == item.novelId && $0.ownerId == uid }
            )
            if try context.fetch(descriptor).isEmpty {
                let viewedAt = Date(timeIntervalSince1970: Double(item.viewedAt) / 1000.0)
                let glance = GlanceNovelPersist(novelId: item.novelId, ownerId: uid)
                glance.viewedAt = viewedAt
                context.insert(glance)
            }
        }

        try enforceGlanceHistoryLimit(context: context)
        try context.save()
    }

    private func replaceGlanceHistory(illustItems: [IllustHistoryItem], novelItems: [NovelHistoryItem]) throws {
        let context = dataContainer.mainContext
        let uid = currentUserId

        try context.delete(model: GlanceIllustPersist.self, where: #Predicate { $0.ownerId == uid })
        try context.delete(model: GlanceNovelPersist.self, where: #Predicate { $0.ownerId == uid })
        try context.save()

        for item in illustItems {
            let viewedAt = Date(timeIntervalSince1970: Double(item.viewedAt) / 1000.0)
            let glance = GlanceIllustPersist(illustId: item.illustId, ownerId: uid)
            glance.viewedAt = viewedAt
            context.insert(glance)
        }

        for item in novelItems {
            let viewedAt = Date(timeIntervalSince1970: Double(item.viewedAt) / 1000.0)
            let glance = GlanceNovelPersist(novelId: item.novelId, ownerId: uid)
            glance.viewedAt = viewedAt
            context.insert(glance)
        }

        try enforceGlanceHistoryLimit(context: context)
        try context.save()
    }

    private func enforceGlanceHistoryLimit(context: ModelContext) throws {
        let maxCount = 100
        let uid = currentUserId

        var illustDescriptor = FetchDescriptor<GlanceIllustPersist>(
            predicate: #Predicate { $0.ownerId == uid }
        )
        illustDescriptor.sortBy = [SortDescriptor(\.viewedAt, order: .reverse)]
        let illustHistory = try context.fetch(illustDescriptor)

        if illustHistory.count > maxCount {
            for item in Array(illustHistory.dropFirst(maxCount)) {
                context.delete(item)
            }
        }

        var novelDescriptor = FetchDescriptor<GlanceNovelPersist>(
            predicate: #Predicate { $0.ownerId == uid }
        )
        novelDescriptor.sortBy = [SortDescriptor(\.viewedAt, order: .reverse)]
        let novelHistory = try context.fetch(novelDescriptor)

        if novelHistory.count > maxCount {
            for item in Array(novelHistory.dropFirst(maxCount)) {
                context.delete(item)
            }
        }
    }

    private func mergeMuteData(banTags: [BanTagItem], banUsers: [BanUserIdItem], banIllusts: [BanIllustIdItem]) throws {
        let context = dataContainer.mainContext
        let uid = currentUserId

        for tag in banTags {
            let descriptor = FetchDescriptor<BanTag>(
                predicate: #Predicate { $0.name == tag.name && $0.ownerId == uid }
            )
            if try context.fetch(descriptor).isEmpty {
                let banTag = BanTag(name: tag.name, ownerId: uid)
                context.insert(banTag)
            }
        }

        for user in banUsers {
            let descriptor = FetchDescriptor<BanUserId>(
                predicate: #Predicate { $0.userId == user.userId && $0.ownerId == uid }
            )
            if try context.fetch(descriptor).isEmpty {
                let banUser = BanUserId(userId: user.userId, ownerId: uid)
                context.insert(banUser)
            }
        }

        for illust in banIllusts {
            let descriptor = FetchDescriptor<BanIllustId>(
                predicate: #Predicate { $0.illustId == illust.illustId && $0.ownerId == uid }
            )
            if try context.fetch(descriptor).isEmpty {
                let banIllust = BanIllustId(illustId: illust.illustId, ownerId: uid)
                context.insert(banIllust)
            }
        }

        try context.save()
        userSettingStore.loadUserSetting()
    }

    private func replaceMuteData(banTags: [BanTagItem], banUsers: [BanUserIdItem], banIllusts: [BanIllustIdItem]) throws {
        let context = dataContainer.mainContext
        let uid = currentUserId

        try context.delete(model: BanTag.self, where: #Predicate { $0.ownerId == uid })
        try context.delete(model: BanUserId.self, where: #Predicate { $0.ownerId == uid })
        try context.delete(model: BanIllustId.self, where: #Predicate { $0.ownerId == uid })
        try context.save()

        for tag in banTags {
            let banTag = BanTag(name: tag.name, ownerId: uid)
            context.insert(banTag)
        }

        for user in banUsers {
            let banUser = BanUserId(userId: user.userId, ownerId: uid)
            context.insert(banUser)
        }

        for illust in banIllusts {
            let banIllust = BanIllustId(illustId: illust.illustId, ownerId: uid)
            context.insert(banIllust)
        }

        try context.save()
        userSettingStore.loadUserSetting()
    }
}

private struct SearchHistoryWrapper: Codable {
    let header: ExportHeader
    let data: SearchHistoryExport
}

private struct GlanceHistoryWrapper: Codable {
    let header: ExportHeader
    let data: GlanceHistoryExport
}

private struct MuteDataWrapper: Codable {
    let header: ExportHeader
    let data: MuteDataExport
}

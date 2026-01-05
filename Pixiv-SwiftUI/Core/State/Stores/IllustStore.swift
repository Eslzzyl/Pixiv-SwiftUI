import Foundation
import Observation
import SwiftData

/// 插画内容状态管理
@Observable
final class IllustStore {
    var illusts: [Illusts] = []
    var favoriteIllusts: [Illusts] = []
    var isLoading: Bool = false
    var error: AppError?

    private let dataContainer = DataContainer.shared

    // MARK: - 插画管理

    /// 保存或更新插画
    func saveIllust(_ illust: Illusts) throws {
        let context = dataContainer.mainContext

        // 检查是否已存在
        let descriptor = FetchDescriptor<Illusts>(
            predicate: #Predicate { $0.id == illust.id }
        )
        if try context.fetch(descriptor).isEmpty {
            context.insert(illust)
        }

        try context.save()
    }

    /// 保存多个插画
    func saveIllusts(_ illusts: [Illusts]) throws {
        let context = dataContainer.mainContext

        for illust in illusts {
            let descriptor = FetchDescriptor<Illusts>(
                predicate: #Predicate { $0.id == illust.id }
            )
            if try context.fetch(descriptor).isEmpty {
                context.insert(illust)
            }
        }

        try context.save()
    }

    /// 获取所有收藏的插画
    func loadFavorites() throws {
        let context = dataContainer.mainContext
        var descriptor = FetchDescriptor<Illusts>(
            predicate: #Predicate { $0.isBookmarked == true }
        )
        descriptor.fetchLimit = 1000
        self.favoriteIllusts = try context.fetch(descriptor)
    }

    /// 获取插画详情
    func getIllust(_ id: Int) throws -> Illusts? {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<Illusts>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    /// 批量获取插画
    func getIllusts(_ ids: [Int]) throws -> [Illusts] {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<Illusts>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        return try context.fetch(descriptor)
    }

    // MARK: - 禁用管理

    /// 禁用插画
    func banIllust(_ illustId: Int) throws {
        let context = dataContainer.mainContext
        let ban = BanIllustId(illustId: illustId)
        context.insert(ban)
        try context.save()
    }

    /// 检查插画是否被禁用
    func isIllustBanned(_ illustId: Int) throws -> Bool {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<BanIllustId>(
            predicate: #Predicate { $0.illustId == illustId }
        )
        return try context.fetch(descriptor).count > 0
    }

    /// 取消禁用插画
    func unbanIllust(_ illustId: Int) throws {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<BanIllustId>(
            predicate: #Predicate { $0.illustId == illustId }
        )
        if let ban = try context.fetch(descriptor).first {
            context.delete(ban)
            try context.save()
        }
    }

    /// 禁用用户
    func banUser(_ userId: String) throws {
        let context = dataContainer.mainContext
        let ban = BanUserId(userId: userId)
        context.insert(ban)
        try context.save()
    }

    /// 检查用户是否被禁用
    func isUserBanned(_ userId: String) throws -> Bool {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<BanUserId>(
            predicate: #Predicate { $0.userId == userId }
        )
        return try context.fetch(descriptor).count > 0
    }

    /// 取消禁用用户
    func unbanUser(_ userId: String) throws {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<BanUserId>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let ban = try context.fetch(descriptor).first {
            context.delete(ban)
            try context.save()
        }
    }

    /// 禁用标签
    func banTag(_ name: String) throws {
        let context = dataContainer.mainContext
        let ban = BanTag(name: name)
        context.insert(ban)
        try context.save()
    }

    /// 检查标签是否被禁用
    func isTagBanned(_ name: String) throws -> Bool {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<BanTag>(
            predicate: #Predicate { $0.name == name }
        )
        return try context.fetch(descriptor).count > 0
    }

    /// 取消禁用标签
    func unbanTag(_ name: String) throws {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<BanTag>(
            predicate: #Predicate { $0.name == name }
        )
        if let ban = try context.fetch(descriptor).first {
            context.delete(ban)
            try context.save()
        }
    }

    // MARK: - 浏览历史

    private let maxGlanceHistoryCount = 100

    /// 记录浏览历史
    func recordGlance(_ illustId: Int) throws {
        let context = dataContainer.mainContext

        let descriptor = FetchDescriptor<GlanceIllustPersist>(
            predicate: #Predicate { $0.illustId == illustId }
        )
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }

        let glance = GlanceIllustPersist(illustId: illustId)
        context.insert(glance)

        try enforceGlanceHistoryLimit(context: context)
        try context.save()
    }

    /// 强制执行浏览历史数量限制
    private func enforceGlanceHistoryLimit(context: ModelContext) throws {
        var descriptor = FetchDescriptor<GlanceIllustPersist>()
        descriptor.sortBy = [SortDescriptor(\.viewedAt, order: .reverse)]
        let allHistory = try context.fetch(descriptor)

        if allHistory.count > maxGlanceHistoryCount {
            let toDelete = Array(allHistory.dropFirst(maxGlanceHistoryCount))
            for item in toDelete {
                context.delete(item)
            }
        }
    }

    /// 获取浏览历史 ID 列表
    func getGlanceHistoryIds(limit: Int = 100) throws -> [Int] {
        let history = try getGlanceHistory(limit: limit)
        return history.map { $0.illustId }
    }

    /// 获取浏览历史
    func getGlanceHistory(limit: Int = 100) throws -> [GlanceIllustPersist] {
        let context = dataContainer.mainContext
        var descriptor = FetchDescriptor<GlanceIllustPersist>()
        descriptor.fetchLimit = limit
        descriptor.sortBy = [SortDescriptor(\.viewedAt, order: .reverse)]
        return try context.fetch(descriptor)
    }

    /// 清空浏览历史
    func clearGlanceHistory() throws {
        let context = dataContainer.mainContext
        try context.delete(model: GlanceIllustPersist.self)
        try context.save()
    }
}

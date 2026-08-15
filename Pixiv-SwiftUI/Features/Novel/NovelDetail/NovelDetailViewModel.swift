import Foundation
import os.log

@MainActor
@Observable
final class NovelDetailViewModel {
    let novel: Novel

    var novelData: Novel
    var isBookmarked: Bool
    var isFollowed: Bool?
    var totalComments: Int?
    var isDeleting = false
    var isExporting = false

    @ObservationIgnored private let accountStore: AccountStore
    @ObservationIgnored private let api: PixivAPI
    @ObservationIgnored private var requestGeneration: UInt = 0

    var showToast: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    init(
        novel: Novel,
        accountStore: AccountStore = .shared,
        api: PixivAPI = .shared
    ) {
        self.novel = novel
        self.novelData = novel
        self.accountStore = accountStore
        self.api = api
        self.isBookmarked = novel.isBookmarked
        self.isFollowed = novel.user.isFollowed
        self.totalComments = novel.totalComments
        NotificationCenter.default.addObserver(
            forName: .accountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.resetForAccountChange()
            }
        }
    }

    // MARK: - Computed

    var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    var isOwnNovel: Bool {
        novel.user.id.stringValue == accountStore.currentUserId
    }

    // MARK: - Bookmark

    func toggleBookmark(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
        guard isLoggedIn else {
            showToast?(String(localized: "请先登录"))
            return
        }

        let wasBookmarked = isBookmarked
        let novelId = novel.id
        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = accountStore.accountGeneration

        if forceUnbookmark && wasBookmarked {
            isBookmarked = false
            novelData.isBookmarked = false
            novelData.totalBookmarks -= 1
        } else if wasBookmarked {
            novelData.isBookmarked = true
        } else {
            isBookmarked = true
            novelData.isBookmarked = true
            novelData.totalBookmarks += 1
        }

        Task {
            do {
                if forceUnbookmark && wasBookmarked {
                    try await api.novelAPI.unbookmarkNovel(novelId: novelId)
                } else if wasBookmarked {
                    try await api.novelAPI.unbookmarkNovel(novelId: novelId)
                    try await api.novelAPI.bookmarkNovel(novelId: novelId, restrict: isPrivate ? "private" : "public")
                } else {
                    try await api.novelAPI.bookmarkNovel(novelId: novelId, restrict: isPrivate ? "private" : "public")
                }
            } catch {
                await MainActor.run {
                    guard self.isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration) else { return }
                    if forceUnbookmark && wasBookmarked {
                        isBookmarked = true
                        novelData.isBookmarked = true
                        novelData.totalBookmarks += 1
                    } else if wasBookmarked {
                        isBookmarked = true
                        novelData.isBookmarked = true
                    } else {
                        isBookmarked = false
                        novelData.isBookmarked = false
                        novelData.totalBookmarks -= 1
                    }
                }
            }
        }
    }

    // MARK: - Data Fetching

    func fetchUserDetailIfNeeded() {
        guard isFollowed == nil else { return }
        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = accountStore.accountGeneration

        Task {
            do {
                let detail = try await api.userAPI.getUserDetail(userId: novel.user.id.stringValue)
                await MainActor.run {
                    guard self.isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration) else { return }
                    self.isFollowed = detail.user.isFollowed
                }
            } catch {
                Logger.novel.error("Failed to fetch user detail: \(error)")
            }
        }
    }

    private func refreshAccountState() {
        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = accountStore.accountGeneration

        Task {
            do {
                let detail = try await api.novelAPI.getNovelDetail(novelId: novel.id)
                guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration) else { return }
                self.novelData = detail
                self.isBookmarked = detail.isBookmarked
                self.isFollowed = detail.user.isFollowed
            } catch {
                Logger.novel.error("Failed to refresh novel account state: \(error)")
            }
        }
    }

    func fetchTotalCommentsIfNeeded() {
        Task {
            do {
                let comments = try await api.novelAPI.getNovelComments(novelId: novel.id)
                await MainActor.run {
                    self.totalComments = comments.comments.count
                }
            } catch {
                Logger.novel.error("Failed to fetch comments: \(error)")
            }
        }
    }

    func recordGlance() {
        let store = NovelStore()
        try? store.recordGlance(novel.id, novel: novelData)
    }

    private func resetForAccountChange() {
        requestGeneration &+= 1
        isBookmarked = false
        isFollowed = nil
        if accountStore.isLoggedIn {
            refreshAccountState()
        }
    }

    private func isCurrentRequest(generation: UInt, accountGeneration: UInt) -> Bool {
        self.requestGeneration == generation && self.accountStore.accountGeneration == accountGeneration
    }

    // MARK: - Export

    func exportNovel(format: NovelExportFormat, customSaveURL: URL? = nil) {
        guard !isExporting else { return }
        isExporting = true

        Task {
            do {
                let content = try await api.novelAPI.getNovelContent(novelId: novel.id)
                await DownloadStore.shared.addNovelTask(
                    novelId: novel.id,
                    title: novel.title,
                    authorName: novel.user.name,
                    coverURL: novel.imageUrls.medium,
                    content: content,
                    format: format,
                    customSaveURL: customSaveURL
                )
                await MainActor.run {
                    self.showToast?(String(localized: "已添加到下载队列"))
                    self.isExporting = false
                }
            } catch {
                Logger.novel.error("导出小说失败: \(error)")
                await MainActor.run {
                    self.isExporting = false
                }
            }
        }
    }

    func exportFilename(format: NovelExportFormat) -> String {
        let safeTitle = novel.title.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return "\(novel.user.name)_\(safeTitle).\(format.fileExtension)"
    }

    // MARK: - Delete

    func deleteNovel() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await api.novelAPI.deleteNovel(novelId: novel.id)
            await MainActor.run {
                self.showToast?(String(localized: "作品已删除"))
                self.onDismiss?()
            }
        } catch {
            await MainActor.run {
                self.showToast?(String(localized: "删除失败"))
            }
        }
    }
}

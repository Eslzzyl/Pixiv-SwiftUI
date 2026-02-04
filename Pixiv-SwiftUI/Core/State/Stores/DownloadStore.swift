import Foundation
import Combine
import os.log
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
final class DownloadStore: ObservableObject {
    static let shared = DownloadStore()

    @Published var tasks: [DownloadTask] = []
    @Published var isProcessing = false

    private var runningTasks: [UUID: Task<Void, Never>] = [:]
    private let maxConcurrentTasks: Int
    private var persistenceKey: String {
        "download_tasks_\(AccountStore.shared.currentUserId)"
    }

    private init() {
        let settingStore = UserSettingStore.shared
        self.maxConcurrentTasks = settingStore.userSetting.maxRunningTask
        loadTasks()
    }

    var downloadingTasks: [DownloadTask] {
        tasks.filter { $0.status == .downloading }
    }

    var waitingTasks: [DownloadTask] {
        tasks.filter { $0.status == .waiting }
    }

    var completedTasks: [DownloadTask] {
        tasks.filter { $0.status == .completed }
    }

    var failedTasks: [DownloadTask] {
        tasks.filter { $0.status == .failed }
    }

    func addTask(_ illust: Illusts, quality: Int, customSaveURL: URL? = nil) async {
        let task = DownloadTask.from(illust: illust, quality: quality)
        var newTask = task
        newTask.customSaveURL = customSaveURL

        if let existingIndex = tasks.firstIndex(where: { $0.illustId == illust.id && $0.status != .completed }) {
            if tasks[existingIndex].status == .completed {
                let retryTask = DownloadTask(
                    id: UUID(),
                    illustId: illust.id,
                    title: illust.title,
                    authorName: illust.user.name,
                    pageCount: illust.pageCount,
                    imageURLs: task.imageURLs,
                    quality: quality,
                    status: .waiting,
                    customSaveURL: customSaveURL
                )
                tasks.append(retryTask)
                saveTasks()
                await processQueue()
            }
        } else {
            tasks.append(newTask)
            saveTasks()
            await processQueue()
        }
    }

    func addUgoiraTask(_ illust: Illusts, customSaveURL: URL? = nil) async {
        let task = DownloadTask.fromUgoira(illust: illust)
        var newTask = task
        newTask.customSaveURL = customSaveURL

        if let existingIndex = tasks.firstIndex(where: { $0.illustId == illust.id && $0.status != .completed }) {
            if tasks[existingIndex].status == .completed {
                let retryTask = DownloadTask.fromUgoira(illust: illust)
                var retryNewTask = retryTask
                retryNewTask.customSaveURL = customSaveURL
                tasks.append(retryNewTask)
                saveTasks()
                await processQueue()
            }
        } else {
            tasks.append(newTask)
            saveTasks()
            await processQueue()
        }
    }

    func addTask(_ task: DownloadTask) async {
        tasks.append(task)
        saveTasks()
        await processQueue()
    }

    func pauseTask(id: UUID) async {
        runningTasks[id]?.cancel()
        runningTasks.removeValue(forKey: id)

        if let index = tasks.firstIndex(where: { $0.id == id }) {
            var task = tasks[index]
            task.status = .paused
            tasks[index] = task
            saveTasks()
        }
    }

    func resumeTask(id: UUID) async {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            var task = tasks[index]
            task.status = .waiting
            tasks[index] = task
            saveTasks()
            await processQueue()
        }
    }

    func cancelTask(id: UUID) async {
        runningTasks[id]?.cancel()
        runningTasks.removeValue(forKey: id)

        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks.remove(at: index)
            saveTasks()
        }
    }

    func retryTask(id: UUID) async {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            var task = tasks[index]
            task.status = .waiting
            task.progress = 0
            task.currentPage = 0
            task.error = nil
            task.savedPaths = []
            task.completedAt = nil
            tasks[index] = task
            saveTasks()
            await processQueue()
        }
    }

    func deleteTask(id: UUID) async {
        runningTasks[id]?.cancel()
        runningTasks.removeValue(forKey: id)

        if let index = tasks.firstIndex(where: { $0.id == id }) {
            let task = tasks[index]
            for path in task.savedPaths {
                try? FileManager.default.removeItem(at: path)
            }
            tasks.remove(at: index)
            saveTasks()
        }
    }

    func clearCompleted() async {
        let completedIds = tasks.filter { $0.status == .completed }.map { $0.id }
        for id in completedIds {
            await deleteTask(id: id)
        }
    }

    func clearAll() async {
        for id in runningTasks.keys {
            await cancelTask(id: id)
        }
        tasks.removeAll()
        saveTasks()
    }

    private func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true

        defer {
            isProcessing = false
        }

        let availableSlots = maxConcurrentTasks - runningTasks.count

        guard availableSlots > 0 else { return }

        let tasksToStart = tasks
            .filter { $0.status == .waiting }
            .prefix(availableSlots)

        for task in tasksToStart {
            guard runningTasks[task.id] == nil else { continue }

            let downloadTask = Task {
                await executeDownload(task: task)
            }

            runningTasks[task.id] = downloadTask

            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                var taskItem = tasks[index]
                taskItem.status = .downloading
                tasks[index] = taskItem
            }
        }

        saveTasks()
    }

    private func executeDownload(task: DownloadTask) async {
        switch task.contentType {
        case .ugoira:
            await executeUgoiraDownload(task: task)
            return
        case .novel:
            await executeNovelDownload(task: task)
            return
        case .novelSeries:
            await executeNovelSeriesDownload(task: task)
            return
        case .image:
            break
        }

        Logger.download.debug("开始下载图片任务: \(task.title, privacy: .public), 页数: \(task.imageURLs.count)")

        var savedPaths: [URL] = []
        var lastError: String?
        var failedPages: [Int] = []

        for (index, urlString) in task.imageURLs.enumerated() {
            Logger.download.debug("下载第 \(index + 1)/\(task.imageURLs.count) 页")

            guard !Task.isCancelled else {
                if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                    var taskItem = tasks[idx]
                    taskItem.status = .waiting
                    taskItem.progress = 0
                    taskItem.currentPage = 0
                    tasks[idx] = taskItem
                }
                return
            }

            do {
                var imageData = try await ImageSaver.downloadImage(from: urlString)

                // 注入元数据
                if UserSettingStore.shared.userSetting.saveMetadata {
                    if let processedData = try? ImageMetadataProcessor.inject(data: imageData, task: task, pageIndex: index) {
                        imageData = processedData
                    }
                }

                let ext = (urlString as NSString).pathExtension.lowercased()
                let actualExt = ext.isEmpty ? "jpg" : ext
                Logger.download.debug("第 \(index + 1) 页下载成功，扩展名: \(actualExt)")

                #if os(iOS)
                try await ImageSaver.saveToPhotosAlbum(data: imageData)
                Logger.download.debug("第 \(index + 1) 页保存到相册成功")
                // swiftlint:disable:next force_unwrapping
                savedPaths.append(URL(string: "photos://\(task.illustId)_\(index)")!)  // iOS 保存到相册，没有文件路径
                #else
                let saveURL: URL
                if let customURL = task.customSaveURL {
                    _ = customURL.startAccessingSecurityScopedResource()
                    defer { customURL.stopAccessingSecurityScopedResource() }

                    if customURL.hasDirectoryPath {
                        let safeTitle = ImageSaver.sanitizeFilename(task.title)
                        let safeAuthor = ImageSaver.sanitizeFilename(task.authorName)
                        var filename = "\(safeAuthor)_\(safeTitle)"
                        if task.imageURLs.count > 1 {
                            filename += "_p\(index)"
                        }
                        filename += ".\(actualExt)"
                        saveURL = customURL.appendingPathComponent(filename)
                    } else {
                        if task.imageURLs.count > 1 {
                            // 警告：如果是单文件路径却要保存多张图，在沙盒下只有第一张能成功
                            // 但通过 UI 限制，这种情况应该较少发生
                            let folder = customURL.deletingLastPathComponent()
                            let originalName = customURL.deletingPathExtension().lastPathComponent
                            saveURL = folder.appendingPathComponent("\(originalName)_p\(index).\(actualExt)")
                        } else {
                            saveURL = customURL
                        }
                    }
                } else {
                    let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?
                        .appendingPathComponent("Pixiv")
                    let baseURL = downloadsURL ?? FileManager.default.homeDirectoryForCurrentUser

                    let safeTitle = ImageSaver.sanitizeFilename(task.title)
                    let safeAuthor = ImageSaver.sanitizeFilename(task.authorName)

                    let authorFolder = baseURL.appendingPathComponent(safeAuthor)
                    try? FileManager.default.createDirectory(at: authorFolder, withIntermediateDirectories: true)

                    var filename = safeTitle
                    if task.imageURLs.count > 1 {
                        filename += "_p\(index)"
                    }
                    filename += ".\(actualExt)"

                    saveURL = authorFolder.appendingPathComponent(filename)
                }

                try await ImageSaver.saveToFile(data: imageData, url: saveURL)
                savedPaths.append(saveURL)
                #endif

                let pageProgress = Double(index + 1) / Double(task.imageURLs.count)

                if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                    var taskItem = tasks[idx]
                    taskItem.progress = pageProgress
                    taskItem.currentPage = index + 1
                    tasks[idx] = taskItem
                }

            } catch {
                Logger.download.error("第 \(index + 1) 页下载/保存失败: \(error.localizedDescription)")
                lastError = error.localizedDescription
                failedPages.append(index)
            }
        }

        runningTasks.removeValue(forKey: task.id)
        Logger.download.info("下载完成，成功: \(savedPaths.count)/\(task.imageURLs.count), 失败: \(failedPages.count)")

        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            var taskItem = tasks[idx]
            taskItem.savedPaths = savedPaths
            taskItem.completedAt = Date()

            if Task.isCancelled {
                Logger.download.debug("任务被取消，恢复等待状态")
                taskItem.status = .waiting
                taskItem.progress = 0
                taskItem.currentPage = 0
            } else if savedPaths.count == task.imageURLs.count {
                Logger.download.info("全部下载成功")
                taskItem.status = .completed
            } else {
                Logger.download.warning("部分失败，失败页码: \(failedPages)")
                taskItem.status = .failed
                taskItem.error = lastError ?? "部分页面下载失败"
            }

            tasks[idx] = taskItem
            saveTasks()
        }

        await processQueue()
    }

    private func executeUgoiraDownload(task: DownloadTask) async {
        Logger.download.debug("开始处理动图任务: \(task.title, privacy: .public)")

        guard !Task.isCancelled else {
            Logger.download.debug("动图任务被取消")
            return
        }

        do {
            // 创建UgoiraStore来获取动图数据
            let ugoiraStore = UgoiraStore(illustId: task.illustId, expiration: .hours(1))

            // 更新状态为下载中
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var taskItem = tasks[idx]
                taskItem.status = .downloading
                taskItem.progress = 0.1
                tasks[idx] = taskItem
            }

            // 加载动图数据
            await ugoiraStore.loadIfNeeded()

            // 如果还没准备好（没有缓存），则开始下载
            if !ugoiraStore.isReady {
                Logger.download.debug("动图未准备好，开始下载: \(task.illustId, privacy: .public)")
                await ugoiraStore.startDownload()
            }

            // 等待动图准备完成
            var attempts = 0
            let maxAttempts = 60 // 最多等待60秒

            while !ugoiraStore.isReady && attempts < maxAttempts {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
                attempts += 1

                // 更新进度
                if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                    var taskItem = tasks[idx]
                    taskItem.progress = min(0.1 + Double(attempts) / Double(maxAttempts) * 0.5, 0.6)
                    tasks[idx] = taskItem
                }

                guard !Task.isCancelled else {
                    Logger.download.debug("动图加载被取消")
                    return
                }
            }

            guard ugoiraStore.isReady, !ugoiraStore.frameURLs.isEmpty else {
                throw DownloadError.ugoiraLoadFailed
            }

            Logger.download.debug("动图数据准备完成，帧数: \(ugoiraStore.frameURLs.count)")

            // 更新进度为导出中
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var taskItem = tasks[idx]
                taskItem.progress = 0.7
                tasks[idx] = taskItem
            }

            // 导出GIF
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(task.illustId)_\(ImageSaver.sanitizeFilename(task.title)).gif")

            try await GIFExporter.export(
                frameURLs: ugoiraStore.frameURLs,
                delays: ugoiraStore.frameDelays,
                outputURL: outputURL
            )

            Logger.download.debug("GIF导出成功: \(outputURL, privacy: .public)")

            // 保存GIF到相册或文件
            var gifData = try Data(contentsOf: outputURL)

            // 注入元数据
            if UserSettingStore.shared.userSetting.saveMetadata {
                if let processedData = try? ImageMetadataProcessor.inject(data: gifData, task: task) {
                    gifData = processedData
                }
            }

            #if os(iOS)
            try await ImageSaver.saveToPhotosAlbum(data: gifData)
            Logger.download.debug("GIF保存到相册成功")
            // swiftlint:disable:next force_unwrapping
            let savedURL = URL(string: "photos://\(task.illustId)_ugoira")!
            #else
            let saveURL: URL
            if let customURL = task.customSaveURL {
                _ = customURL.startAccessingSecurityScopedResource()
                defer { customURL.stopAccessingSecurityScopedResource() }

                if customURL.hasDirectoryPath {
                    let safeTitle = ImageSaver.sanitizeFilename(task.title)
                    let safeAuthor = ImageSaver.sanitizeFilename(task.authorName)
                    let filename = "\(safeAuthor)_\(safeTitle).gif"
                    saveURL = customURL.appendingPathComponent(filename)
                } else {
                    saveURL = customURL
                }
            } else {
                let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?
                    .appendingPathComponent("Pixiv")
                let baseURL = downloadsURL ?? FileManager.default.homeDirectoryForCurrentUser

                let safeTitle = ImageSaver.sanitizeFilename(task.title)
                let safeAuthor = ImageSaver.sanitizeFilename(task.authorName)

                let authorFolder = baseURL.appendingPathComponent(safeAuthor)
                try? FileManager.default.createDirectory(at: authorFolder, withIntermediateDirectories: true)

                let filename = "\(safeAuthor)_\(safeTitle).gif"
                saveURL = authorFolder.appendingPathComponent(filename)
            }

            try await ImageSaver.saveToFile(data: gifData, url: saveURL)
            Logger.download.debug("GIF保存到文件成功: \(saveURL, privacy: .public)")
            let savedURL = saveURL
            #endif

            // 清理临时文件
            try? FileManager.default.removeItem(at: outputURL)

            // 更新任务状态为完成
            runningTasks.removeValue(forKey: task.id)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var taskItem = tasks[idx]
                taskItem.status = .completed
                taskItem.progress = 1.0
                taskItem.savedPaths = [savedURL]
                taskItem.completedAt = Date()
                tasks[idx] = taskItem
            }

            Logger.download.info("动图任务完成: \(task.title, privacy: .public)")

        } catch {
            Logger.download.error("动图任务失败: \(error)")

            runningTasks.removeValue(forKey: task.id)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var taskItem = tasks[idx]
                taskItem.status = .failed
                taskItem.error = error.localizedDescription
                tasks[idx] = taskItem
            }
        }

        saveTasks()
        await processQueue()
    }

    private func saveTasks() {
        do {
            let data = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            Logger.download.error("保存任务失败: \(error)")
        }
    }

    func loadTasks() {
        tasks = [] // 清空当前任务
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        do {
            tasks = try JSONDecoder().decode([DownloadTask].self, from: data)
            tasks = tasks.filter { $0.status != .completed ||
                (($0.completedAt ?? Date()).timeIntervalSinceNow > -7 * 24 * 60 * 60) }
        } catch {
            Logger.download.error("加载任务失败: \(error)")
            tasks = []
        }
    }

    // MARK: - 小说导出任务

    func addNovelTask(novelId: Int, title: String, authorName: String, coverURL: String, content: NovelReaderContent, format: NovelExportFormat, customSaveURL: URL? = nil) async {
        let task = DownloadTask.fromNovel(novelId: novelId, title: title, authorName: authorName, coverURL: coverURL, content: content, format: format)
        var newTask = task
        newTask.customSaveURL = customSaveURL
        tasks.append(newTask)
        saveTasks()
        await processQueue()
    }

    func addNovelSeriesTask(seriesId: Int, seriesTitle: String, authorName: String, novels: [Novel], format: NovelExportFormat, customSaveURL: URL? = nil) async {
        let task = DownloadTask.fromNovelSeries(seriesId: seriesId, seriesTitle: seriesTitle, authorName: authorName, novels: novels, format: format)
        var newTask = task
        newTask.customSaveURL = customSaveURL
        tasks.append(newTask)
        saveTasks()
        await processQueue()
    }

    private func executeNovelDownload(task: DownloadTask) async {
        Logger.download.debug("开始导出小说任务: \(task.title, privacy: .public)")

        guard let metadata = task.metadata,
              let format = metadata.novelFormat else {
            runningTasks.removeValue(forKey: task.id)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var taskItem = tasks[idx]
                taskItem.status = .failed
                taskItem.error = "导出格式缺失"
                tasks[idx] = taskItem
            }
            saveTasks()
            await processQueue()
            return
        }

        do {
            // 获取小说内容
            let content = NovelReaderContent(
                id: task.illustId,
                title: task.title,
                seriesId: metadata.seriesId,
                seriesTitle: metadata.seriesTitle,
                seriesIsWatched: nil as Bool?,
                userId: 0,
                coverUrl: nil as String?,
                tags: metadata.tags,
                caption: metadata.caption,
                createDate: metadata.createDate,
                totalView: 0,
                totalBookmarks: 0,
                isBookmarked: nil as Bool?,
                xRestrict: nil as Int?,
                novelAIType: nil as Int?,
                marker: nil as String?,
                text: metadata.novelText ?? "",
                illusts: nil as [NovelIllustData]?,
                images: nil as [NovelUploadedImage]?,
                seriesNavigation: nil as SeriesNavigation?
            )

            // 导出为指定格式
            let data: Data
            switch format {
            case .txt:
                data = try await NovelExporter.exportAsTXT(novelId: task.illustId, title: task.title, authorName: task.authorName, content: content)
            case .epub:
                data = try await NovelExporter.exportAsEPUB(
                    novelId: task.illustId,
                    title: task.title,
                    authorName: task.authorName,
                    coverURL: task.imageURLs.first,
                    content: content
                )
            }

            let filename = NovelExporter.buildFilename(novelId: task.illustId, title: task.title, authorName: task.authorName, format: format)

            // 保存文件
            #if os(iOS)
            let savedURL: URL
            if let customURL = task.customSaveURL {
                let targetURL = customURL.appendingPathComponent(filename)
                try data.write(to: targetURL)
                savedURL = targetURL
            } else {
                // 保存到临时目录，然后通过 Notification 通知 UI 层显示 DocumentPicker
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try data.write(to: tempURL)
                savedURL = tempURL
                // 通知 UI 层显示文件保存对话框
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .novelExportDidComplete,
                        object: nil,
                        userInfo: ["tempURL": tempURL, "filename": filename]
                    )
                }
            }
            #else
            let savedURL: URL
            if let customURL = task.customSaveURL {
                if customURL.hasDirectoryPath {
                    let targetURL = customURL.appendingPathComponent(filename)
                    try data.write(to: targetURL)
                    savedURL = targetURL
                } else {
                    try data.write(to: customURL)
                    savedURL = customURL
                }
            } else {
                // 默认保存到下载目录
                let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?
                    .appendingPathComponent("PixivNovels")
                let baseURL = downloadsURL ?? FileManager.default.homeDirectoryForCurrentUser

                let authorFolder = baseURL.appendingPathComponent(NovelExporter.sanitizeFilename(task.authorName))
                try? FileManager.default.createDirectory(at: authorFolder, withIntermediateDirectories: true)

                let targetURL = authorFolder.appendingPathComponent(filename)
                try data.write(to: targetURL)
                savedURL = targetURL
            }
            #endif

            runningTasks.removeValue(forKey: task.id)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var taskItem = tasks[idx]
                taskItem.status = .completed
                taskItem.progress = 1.0
                taskItem.savedPaths = [savedURL]
                taskItem.completedAt = Date()
                tasks[idx] = taskItem
            }

            Logger.download.info("小说导出成功: \(savedURL.path, privacy: .public)")

        } catch {
            Logger.download.error("小说导出失败: \(error)")

            runningTasks.removeValue(forKey: task.id)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var taskItem = tasks[idx]
                taskItem.status = .failed
                taskItem.error = error.localizedDescription
                tasks[idx] = taskItem
            }
        }

        saveTasks()
        await processQueue()
    }

    // swiftlint:disable cyclomatic_complexity
    private func executeNovelSeriesDownload(task: DownloadTask) async {
        Logger.download.debug("开始导出系列任务: \(task.title, privacy: .public), 共 \(task.pageCount) 章")

        guard let metadata = task.metadata,
              let format = metadata.novelFormat,
              let chapters = metadata.seriesChapters, !chapters.isEmpty else {
            runningTasks.removeValue(forKey: task.id)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var taskItem = tasks[idx]
                taskItem.status = .failed
                taskItem.error = "系列章节信息缺失"
                tasks[idx] = taskItem
            }
            saveTasks()
            await processQueue()
            return
        }

        do {
            var novelsWithContent: [(novel: Novel, content: NovelReaderContent)] = []
            let totalChapters = chapters.count
            var failedChapters: [Int] = []
            var allNovels: [Novel] = []

            // 从上次中断位置继续（如果是恢复）
            let startIndex = task.currentPage

            // 第一阶段：下载所有小说内容（50%）
            for (index, chapter) in chapters.enumerated() {
                // 如果是恢复任务，跳过已下载的章节
                if index < startIndex {
                    Logger.download.debug("跳过已下载的第 \(index + 1) 章")
                    continue
                }

                guard !Task.isCancelled else {
                    Logger.download.debug("系列导出被取消")
                    if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                        var taskItem = tasks[idx]
                        taskItem.status = .paused
                        taskItem.currentPage = index
                        tasks[idx] = taskItem
                    }
                    saveTasks()
                    return
                }

                do {
                    Logger.download.debug("正在下载第 \(index + 1)/\(totalChapters) 章: \(chapter.title, privacy: .public)")

                    // 重试最多3次
                    var retries = 0
                    let maxRetries = 3
                    var content: NovelReaderContent?
                    var novel: Novel?

                    while retries < maxRetries && content == nil {
                        do {
                            content = try await PixivAPI.shared.getNovelContent(novelId: chapter.novelId)

                            // 从 API 获取小说基本信息 - 通过小说详情端点
                            if let novelContent = content {
                                // 从小说内容中提取用户信息
                                // 这里我们临时构造一个 Novel 对象
                                novel = Novel(
                                    id: chapter.novelId,
                                    title: chapter.title,
                                    caption: novelContent.caption,
                                    restrict: novelContent.xRestrict ?? 0,
                                    xRestrict: novelContent.xRestrict ?? 0,
                                    isOriginal: false,
                                    imageUrls: ImageUrls(
                                        squareMedium: novelContent.coverUrl ?? "",
                                        medium: novelContent.coverUrl ?? "",
                                        large: novelContent.coverUrl ?? ""
                                    ),
                                    createDate: novelContent.createDate,
                                    tags: novelContent.tags.map { NovelTag(name: $0, translatedName: nil, addedByUploadedUser: false) },
                                    pageCount: 1,
                                    textLength: novelContent.text.count,
                                    user: User(
                                        profileImageUrls: ProfileImageUrls(medium: ""),
                                        id: StringIntValue.int(0),
                                        name: task.authorName,
                                        account: ""
                                    ),
                                    series: nil,
                                    isBookmarked: false,
                                    bookmarkRestrict: nil,
                                    totalBookmarks: 0,
                                    totalView: novelContent.totalView,
                                    visible: true,
                                    isMuted: false,
                                    isMypixivOnly: false,
                                    isXRestricted: (novelContent.xRestrict ?? 0) > 0,
                                    novelAIType: novelContent.novelAIType ?? 0,
                                    totalComments: nil
                                )
                            }

                            break
                        } catch {
                            retries += 1
                            Logger.download.warning("第 \(chapter.title, privacy: .public) 章下载失败，重试 \(retries)/\(maxRetries): \(error)")
                            if retries < maxRetries {
                                try await Task.sleep(nanoseconds: 1_000_000_000)  // 等待1秒后重试
                            }
                        }
                    }

                    if let content = content, let novel = novel {
                        novelsWithContent.append((novel: novel, content: content))
                        allNovels.append(novel)
                        Logger.download.debug("第 \(index + 1) 章下载成功")
                    } else {
                        failedChapters.append(index)
                        Logger.download.error("第 \(index + 1) 章 (\(chapter.title, privacy: .public)) 下载失败，超过最大重试次数")
                    }

                    // 更新进度
                    await MainActor.run {
                        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                            var taskItem = tasks[idx]
                            taskItem.progress = Double(index + 1) / Double(totalChapters) * 0.5  // 50% for downloading
                            taskItem.currentPage = index + 1
                            tasks[idx] = taskItem
                        }
                    }

                } catch {
                    Logger.download.error("处理第 \(index + 1) 章时出错: \(error)")
                    failedChapters.append(index)
                }
            }

            // 检查是否有足够的章节用于导出（至少要有一章）
            guard !novelsWithContent.isEmpty else {
                throw NSError(domain: "NovelSeriesExport", code: -1, userInfo: [NSLocalizedDescriptionKey: "所有章节下载均失败"])
            }

            Logger.download.info("已下载 \(novelsWithContent.count) 章，失败 \(failedChapters.count) 章")

            // 第二阶段：生成导出文件（30%）
            let filename = NovelExporter.buildFilename(
                novelId: task.illustId,
                title: task.title,
                authorName: task.authorName,
                format: format,
                isSeries: true
            )

            let data: Data
            switch format {
            case .txt:
                data = try await NovelExporter.exportSeriesAsTXT(
                    seriesId: task.illustId,
                    seriesTitle: task.title,
                    authorName: task.authorName,
                    novels: novelsWithContent
                )
            case .epub:
                data = try await NovelExporter.exportSeriesAsEPUB(
                    seriesId: task.illustId,
                    seriesTitle: task.title,
                    authorName: task.authorName,
                    novels: novelsWithContent
                )
            }

            await MainActor.run {
                if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                    var taskItem = tasks[idx]
                    taskItem.progress = 0.8  // 80% done
                    tasks[idx] = taskItem
                }
            }

            // 第三阶段：保存文件（20%）
            #if os(iOS)
            let savedURL: URL
            if let customURL = task.customSaveURL {
                let targetURL = customURL.appendingPathComponent(filename)
                try data.write(to: targetURL)
                savedURL = targetURL
            } else {
                // 保存到临时目录，然后通过 Notification 通知 UI 层显示 DocumentPicker
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try data.write(to: tempURL)
                savedURL = tempURL
                // 通知 UI 层显示文件保存对话框
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .novelExportDidComplete,
                        object: nil,
                        userInfo: ["tempURL": tempURL, "filename": filename]
                    )
                }
            }
            #else
            let savedURL: URL
            if let customURL = task.customSaveURL {
                if customURL.hasDirectoryPath {
                    let targetURL = customURL.appendingPathComponent(filename)
                    try data.write(to: targetURL)
                    savedURL = targetURL
                } else {
                    try data.write(to: customURL)
                    savedURL = customURL
                }
            } else {
                // 默认保存到下载目录
                let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?
                    .appendingPathComponent("PixivNovels")
                let baseURL = downloadsURL ?? FileManager.default.homeDirectoryForCurrentUser

                let authorFolder = baseURL.appendingPathComponent(NovelExporter.sanitizeFilename(task.authorName))
                try? FileManager.default.createDirectory(at: authorFolder, withIntermediateDirectories: true)

                let targetURL = authorFolder.appendingPathComponent(filename)
                try data.write(to: targetURL)
                savedURL = targetURL
            }
            #endif

            runningTasks.removeValue(forKey: task.id)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var taskItem = tasks[idx]
                taskItem.status = .completed
                taskItem.progress = 1.0
                taskItem.savedPaths = [savedURL]
                taskItem.completedAt = Date()

                // 如果有失败的章节，记录在错误信息中
                if !failedChapters.isEmpty {
                    taskItem.error = "部分章节下载失败: \(failedChapters.map { String($0 + 1) }.joined(separator: ","))"
                }

                tasks[idx] = taskItem
            }

            Logger.download.info("系列导出成功: \(savedURL.path, privacy: .public)")

        } catch {
            Logger.download.error("系列导出失败: \(error)")

            runningTasks.removeValue(forKey: task.id)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var taskItem = tasks[idx]
                taskItem.status = .failed
                taskItem.error = error.localizedDescription
                tasks[idx] = taskItem
            }
        }

        saveTasks()
        await processQueue()
    }
    // swiftlint:enable cyclomatic_complexity

}

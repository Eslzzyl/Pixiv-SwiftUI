import Foundation
import Combine
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
    private let persistenceKey = "download_tasks"
    
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
                var t = tasks[index]
                t.status = .downloading
                tasks[index] = t
            }
        }
        
        saveTasks()
    }
    
    private func executeDownload(task: DownloadTask) async {
        if task.contentType == .ugoira {
            await executeUgoiraDownload(task: task)
            return
        }
        
        print("[DownloadStore] 开始下载图片任务: \(task.title), 页数: \(task.imageURLs.count)")
        
        var savedPaths: [URL] = []
        var lastError: String?
        var failedPages: [Int] = []
        
        for (index, urlString) in task.imageURLs.enumerated() {
            print("[DownloadStore] 下载第 \(index + 1)/\(task.imageURLs.count) 页")
            
            guard !Task.isCancelled else {
                if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                    var t = tasks[idx]
                    t.status = .waiting
                    t.progress = 0
                    t.currentPage = 0
                    tasks[idx] = t
                }
                return
            }
            
            do {
                let imageData = try await ImageSaver.downloadImage(from: urlString)
                print("[DownloadStore] 第 \(index + 1) 页下载成功，准备保存")
                
                #if os(iOS)
                try await ImageSaver.saveToPhotosAlbum(data: imageData)
                print("[DownloadStore] 第 \(index + 1) 页保存到相册成功")
                savedPaths.append(URL(string: "photos://\(task.illustId)_\(index)")!)  // iOS 保存到相册，没有文件路径
                #else
                let saveURL: URL
                if let customURL = task.customSaveURL {
                    if customURL.hasDirectoryPath {
                        let safeTitle = ImageSaver.sanitizeFilename(task.title)
                        let safeAuthor = ImageSaver.sanitizeFilename(task.authorName)
                        var filename = "\(safeAuthor)_\(safeTitle)"
                        if task.imageURLs.count > 1 {
                            filename += "_p\(index)"
                        }
                        filename += ".jpg"
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
                    
                    var filename = safeTitle
                    if task.imageURLs.count > 1 {
                        filename += "_p\(index)"
                    }
                    filename += ".jpg"
                    
                    saveURL = authorFolder.appendingPathComponent(filename)
                }
                
                try await ImageSaver.saveToFile(data: imageData, url: saveURL)
                savedPaths.append(saveURL)
                #endif
                
                let pageProgress = Double(index + 1) / Double(task.imageURLs.count)
                
                if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                    var t = tasks[idx]
                    t.progress = pageProgress
                    t.currentPage = index + 1
                    tasks[idx] = t
                }
                
            } catch {
                print("[DownloadStore] 第 \(index + 1) 页下载/保存失败: \(error.localizedDescription)")
                lastError = error.localizedDescription
                failedPages.append(index)
            }
        }
        
        runningTasks.removeValue(forKey: task.id)
        print("[DownloadStore] 下载完成，成功: \(savedPaths.count)/\(task.imageURLs.count), 失败: \(failedPages.count)")
        
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            var t = tasks[idx]
            t.savedPaths = savedPaths
            t.completedAt = Date()
            
            if Task.isCancelled {
                print("[DownloadStore] 任务被取消，恢复等待状态")
                t.status = .waiting
                t.progress = 0
                t.currentPage = 0
            } else if savedPaths.count == task.imageURLs.count {
                print("[DownloadStore] 全部下载成功")
                t.status = .completed
            } else {
                print("[DownloadStore] 部分失败，失败页码: \(failedPages)")
                t.status = .failed
                t.error = lastError ?? "部分页面下载失败"
            }
            
            tasks[idx] = t
            saveTasks()
        }
        
        await processQueue()
    }
    
    private func executeUgoiraDownload(task: DownloadTask) async {
        print("[DownloadStore] 开始处理动图任务: \(task.title)")
        
        guard !Task.isCancelled else {
            print("[DownloadStore] 动图任务被取消")
            return
        }
        
        do {
            // 创建UgoiraStore来获取动图数据
            let ugoiraStore = UgoiraStore(illustId: task.illustId, expiration: .hours(1))
            
            // 更新状态为下载中
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var t = tasks[idx]
                t.status = .downloading
                t.progress = 0.1
                tasks[idx] = t
            }
            
            // 加载动图数据
            await ugoiraStore.loadIfNeeded()
            
            // 等待动图准备完成
            var attempts = 0
            let maxAttempts = 60 // 最多等待60秒
            
            while !ugoiraStore.isReady && attempts < maxAttempts {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
                attempts += 1
                
                // 更新进度
                if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                    var t = tasks[idx]
                    t.progress = min(0.1 + Double(attempts) / Double(maxAttempts) * 0.5, 0.6)
                    tasks[idx] = t
                }
                
                guard !Task.isCancelled else {
                    print("[DownloadStore] 动图加载被取消")
                    return
                }
            }
            
            guard ugoiraStore.isReady, !ugoiraStore.frameURLs.isEmpty else {
                throw DownloadError.ugoiraLoadFailed
            }
            
            print("[DownloadStore] 动图数据准备完成，帧数: \(ugoiraStore.frameURLs.count)")
            
            // 更新进度为导出中
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var t = tasks[idx]
                t.progress = 0.7
                tasks[idx] = t
            }
            
            // 导出GIF
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(task.illustId)_\(ImageSaver.sanitizeFilename(task.title)).gif")
            
            try await GIFExporter.export(
                frameURLs: ugoiraStore.frameURLs,
                delays: ugoiraStore.frameDelays,
                outputURL: outputURL
            )
            
            print("[DownloadStore] GIF导出成功: \(outputURL)")
            
            // 保存GIF到相册或文件
            let gifData = try Data(contentsOf: outputURL)
            
            #if os(iOS)
            try await ImageSaver.saveToPhotosAlbum(data: gifData)
            print("[DownloadStore] GIF保存到相册成功")
            let savedURL = URL(string: "photos://\(task.illustId)_ugoira")!
            #else
            let saveURL: URL
            if let customURL = task.customSaveURL {
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
            print("[DownloadStore] GIF保存到文件成功: \(saveURL)")
            let savedURL = saveURL
            #endif
            
            // 清理临时文件
            try? FileManager.default.removeItem(at: outputURL)
            
            // 更新任务状态为完成
            runningTasks.removeValue(forKey: task.id)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var t = tasks[idx]
                t.status = .completed
                t.progress = 1.0
                t.savedPaths = [savedURL]
                t.completedAt = Date()
                tasks[idx] = t
            }
            
            print("[DownloadStore] 动图任务完成: \(task.title)")
            
        } catch {
            print("[DownloadStore] 动图任务失败: \(error)")
            
            runningTasks.removeValue(forKey: task.id)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var t = tasks[idx]
                t.status = .failed
                t.error = error.localizedDescription
                tasks[idx] = t
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
            print("[DownloadStore] 保存任务失败: \(error)")
        }
    }
    
    private func loadTasks() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        do {
            tasks = try JSONDecoder().decode([DownloadTask].self, from: data)
            tasks = tasks.filter { $0.status != .completed || 
                (($0.completedAt ?? Date()).timeIntervalSinceNow > -7 * 24 * 60 * 60) }
        } catch {
            print("[DownloadStore] 加载任务失败: \(error)")
            tasks = []
        }
    }
}

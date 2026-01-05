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
        print("[DownloadStore] 开始下载任务: \(task.title), 页数: \(task.imageURLs.count)")
        
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

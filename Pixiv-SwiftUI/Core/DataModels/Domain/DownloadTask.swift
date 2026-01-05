import Foundation

enum DownloadStatus: String, Codable, Sendable {
    case waiting
    case downloading
    case paused
    case completed
    case failed
}

struct DownloadTask: Identifiable, Codable, Sendable {
    let id: UUID
    let illustId: Int
    let title: String
    let authorName: String
    let pageCount: Int
    let imageURLs: [String]
    let quality: Int
    var status: DownloadStatus
    var progress: Double
    var currentPage: Int
    var savedPaths: [URL]
    var error: String?
    var createdAt: Date
    var completedAt: Date?
    var customSaveURL: URL?
    
    init(
        id: UUID = UUID(),
        illustId: Int,
        title: String,
        authorName: String,
        pageCount: Int,
        imageURLs: [String],
        quality: Int,
        status: DownloadStatus = .waiting,
        progress: Double = 0,
        currentPage: Int = 0,
        savedPaths: [URL] = [],
        error: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        customSaveURL: URL? = nil
    ) {
        self.id = id
        self.illustId = illustId
        self.title = title
        self.authorName = authorName
        self.pageCount = pageCount
        self.imageURLs = imageURLs
        self.quality = quality
        self.status = status
        self.progress = progress
        self.currentPage = currentPage
        self.savedPaths = savedPaths
        self.error = error
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.customSaveURL = customSaveURL
    }
    
    var displayProgress: String {
        switch status {
        case .downloading:
            return "\(currentPage)/\(pageCount) - \(Int(progress * 100))%"
        case .completed:
            return "已完成"
        case .failed:
            return "失败"
        case .paused:
            return "已暂停"
        case .waiting:
            return "等待中"
        }
    }
    
    var thumbnailURL: URL? {
        guard let first = imageURLs.first else { return nil }
        return URL(string: first)
    }
}

extension DownloadTask {
    static func from(illust: Illusts, quality: Int) -> DownloadTask {
        let qualitySetting = quality
        var imageURLs: [String] = []
        
        if !illust.metaPages.isEmpty {
            imageURLs = illust.metaPages.enumerated().compactMap { index, _ in
                ImageURLHelper.getPageImageURL(from: illust, page: index, quality: qualitySetting)
            }
        } else {
            imageURLs = [ImageURLHelper.getImageURL(from: illust, quality: qualitySetting)]
        }
        
        return DownloadTask(
            illustId: illust.id,
            title: illust.title,
            authorName: illust.user.name,
            pageCount: illust.pageCount > 0 ? illust.pageCount : imageURLs.count,
            imageURLs: imageURLs,
            quality: qualitySetting
        )
    }
}

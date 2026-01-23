import Foundation

enum DownloadStatus: String, Codable, Sendable {
    case waiting
    case downloading
    case paused
    case completed
    case failed
}

enum DownloadContentType: String, Codable, Sendable {
    case image
    case ugoira
}

enum DownloadError: LocalizedError {
    case ugoiraLoadFailed

    var errorDescription: String? {
        switch self {
        case .ugoiraLoadFailed:
            return "动图加载失败"
        }
    }
}

struct DownloadTask: Identifiable, Codable, Sendable {
    let id: UUID
    let illustId: Int
    let title: String
    let authorName: String
    let pageCount: Int
    let imageURLs: [String]
    let quality: Int
    var contentType: DownloadContentType
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
        contentType: DownloadContentType = .image,
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
        self.contentType = contentType
        self.status = status
        self.progress = progress
        self.currentPage = currentPage
        self.savedPaths = savedPaths
        self.error = error
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.customSaveURL = customSaveURL
    }

    enum CodingKeys: String, CodingKey {
        case id
        case illustId
        case title
        case authorName
        case pageCount
        case imageURLs
        case quality
        case contentType
        case status
        case progress
        case currentPage
        case savedPaths
        case error
        case createdAt
        case completedAt
        case customSaveURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        illustId = try container.decode(Int.self, forKey: .illustId)
        title = try container.decode(String.self, forKey: .title)
        authorName = try container.decode(String.self, forKey: .authorName)
        pageCount = try container.decode(Int.self, forKey: .pageCount)
        imageURLs = try container.decode([String].self, forKey: .imageURLs)
        quality = try container.decode(Int.self, forKey: .quality)
        contentType = (try? container.decodeIfPresent(DownloadContentType.self, forKey: .contentType)) ?? .image
        status = try container.decode(DownloadStatus.self, forKey: .status)
        progress = try container.decode(Double.self, forKey: .progress)
        currentPage = try container.decode(Int.self, forKey: .currentPage)
        savedPaths = try container.decode([URL].self, forKey: .savedPaths)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        customSaveURL = try container.decodeIfPresent(URL.self, forKey: .customSaveURL)
    }

    var displayProgress: String {
        switch status {
        case .downloading:
            if contentType == .ugoira {
                return "处理中 - \(Int(progress * 100))%"
            } else {
                return "\(currentPage)/\(pageCount) - \(Int(progress * 100))%"
            }
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

    static func fromUgoira(illust: Illusts) -> DownloadTask {
        return DownloadTask(
            illustId: illust.id,
            title: illust.title,
            authorName: illust.user.name,
            pageCount: 1, // 动图作为一个整体
            imageURLs: [], // 动图不需要静态图片URL
            quality: 0, // 动图不适用质量设置
            contentType: .ugoira
        )
    }
}

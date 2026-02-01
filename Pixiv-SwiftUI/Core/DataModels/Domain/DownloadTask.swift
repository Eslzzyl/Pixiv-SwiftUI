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
    case novel
    case novelSeries
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

struct DownloadTaskMetadata: Codable, Sendable {
    let caption: String
    let tags: [String]
    let createDate: String
    let novelText: String?
    let novelFormat: NovelExportFormat?
    let seriesId: Int?
    let seriesTitle: String?

    enum CodingKeys: String, CodingKey {
        case caption
        case tags
        case createDate
        case novelText
        case novelFormat
        case seriesId
        case seriesTitle
    }

    init(
        caption: String,
        tags: [String],
        createDate: String,
        novelText: String? = nil,
        novelFormat: NovelExportFormat? = nil,
        seriesId: Int? = nil,
        seriesTitle: String? = nil
    ) {
        self.caption = caption
        self.tags = tags
        self.createDate = createDate
        self.novelText = novelText
        self.novelFormat = novelFormat
        self.seriesId = seriesId
        self.seriesTitle = seriesTitle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        caption = try container.decode(String.self, forKey: .caption)
        tags = try container.decode([String].self, forKey: .tags)
        createDate = try container.decode(String.self, forKey: .createDate)
        novelText = try container.decodeIfPresent(String.self, forKey: .novelText)
        novelFormat = try container.decodeIfPresent(NovelExportFormat.self, forKey: .novelFormat)
        seriesId = try container.decodeIfPresent(Int.self, forKey: .seriesId)
        seriesTitle = try container.decodeIfPresent(String.self, forKey: .seriesTitle)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(caption, forKey: .caption)
        try container.encode(tags, forKey: .tags)
        try container.encode(createDate, forKey: .createDate)
        try container.encodeIfPresent(novelText, forKey: .novelText)
        try container.encodeIfPresent(novelFormat, forKey: .novelFormat)
        try container.encodeIfPresent(seriesId, forKey: .seriesId)
        try container.encodeIfPresent(seriesTitle, forKey: .seriesTitle)
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
    var metadata: DownloadTaskMetadata?

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
        customSaveURL: URL? = nil,
        metadata: DownloadTaskMetadata? = nil
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
        self.metadata = metadata
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
        case metadata
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
        metadata = try container.decodeIfPresent(DownloadTaskMetadata.self, forKey: .metadata)
    }

    var displayProgress: String {
        switch status {
        case .downloading:
            if contentType == .ugoira {
                return "处理中 - \(Int(progress * 100))%"
            } else if contentType == .novel {
                return "导出中 - \(Int(progress * 100))%"
            } else if contentType == .novelSeries {
                return "导出中 \(currentPage)/\(pageCount) - \(Int(progress * 100))%"
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
            imageURLs = illust.metaPages.indices.compactMap { index in
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
            quality: qualitySetting,
            metadata: DownloadTaskMetadata(
                caption: illust.caption,
                tags: illust.tags.map { $0.name },
                createDate: illust.createDate
            )
        )
    }

    static func fromUgoira(illust: Illusts) -> DownloadTask {
        return DownloadTask(
            illustId: illust.id,
            title: illust.title,
            authorName: illust.user.name,
            pageCount: 1, // 动图作为一个整体
            imageURLs: [illust.imageUrls.medium], // 使用预览图作为缩略图
            quality: 0, // 动图不适用质量设置
            contentType: .ugoira,
            metadata: DownloadTaskMetadata(
                caption: illust.caption,
                tags: illust.tags.map { $0.name },
                createDate: illust.createDate
            )
        )
    }

    static func fromNovel(novelId: Int, title: String, authorName: String, coverURL: String, content: NovelReaderContent, format: NovelExportFormat) -> DownloadTask {
        return DownloadTask(
            illustId: novelId,
            title: title,
            authorName: authorName,
            pageCount: 1,
            imageURLs: [coverURL],
            quality: 0,
            contentType: .novel,
            metadata: DownloadTaskMetadata(
                caption: content.caption,
                tags: content.tags,
                createDate: content.createDate,
                novelText: content.text,
                novelFormat: format,
                seriesId: content.seriesId,
                seriesTitle: content.seriesTitle
            )
        )
    }

    static func fromNovelSeries(seriesId: Int, seriesTitle: String, authorName: String, novelCount: Int) -> DownloadTask {
        return DownloadTask(
            illustId: seriesId,
            title: seriesTitle,
            authorName: authorName,
            pageCount: novelCount,
            imageURLs: [],
            quality: 0,
            contentType: .novelSeries,
            metadata: DownloadTaskMetadata(
                caption: "",
                tags: [],
                createDate: ""
            )
        )
    }
}

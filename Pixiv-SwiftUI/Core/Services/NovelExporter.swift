import Foundation

enum NovelExportError: LocalizedError {
    case missingContent
    case writeFailed(String)
    case invalidURL
    case seriesNotLoaded

    var errorDescription: String? {
        switch self {
        case .missingContent:
            return String(localized: "小说内容缺失")
        case .writeFailed(let msg):
            return String(localized: "写入失败: \(msg)")
        case .invalidURL:
            return String(localized: "无效的保存路径")
        case .seriesNotLoaded:
            return String(localized: "系列内容未加载")
        }
    }
}

struct NovelExporter {

    static func exportAsTXT(novelId: Int, title: String, authorName: String, content: NovelReaderContent) async throws -> Data {
        var output = ""
        output += "\(title)\n"
        output += String(localized: "作者") + ": \(authorName)\n"
        if let seriesTitle = content.seriesTitle, !seriesTitle.isEmpty {
            output += String(localized: "系列") + ": \(seriesTitle)\n"
        }
        output += String(localized: "标签") + ": \(content.tags.joined(separator: ", "))\n"
        output += String(localized: "创建时间") + ": \(content.createDate)\n"
        output += String(localized: "原文链接") + ": https://www.pixiv.net/novel/show.php?id=\(novelId)\n"
        output += "\n"
        if !content.caption.isEmpty {
            output += String(localized: "简介") + ":\n"
            output += content.caption.stripHTML()
            output += "\n\n"
        }
        output += String(localized: "正文") + ":\n\n"
        output += content.text.stripHTML()

        guard let data = output.data(using: .utf8) else {
            throw NovelExportError.writeFailed("UTF-8 encoding failed")
        }
        return data
    }

    static func exportSeriesAsTXT(seriesId: Int, seriesTitle: String, authorName: String, novels: [(novel: Novel, content: NovelReaderContent)]) async throws -> Data {
        guard !novels.isEmpty else {
            throw NovelExportError.seriesNotLoaded
        }

        var output = ""
        output += "\(seriesTitle)\n"
        output += String(localized: "作者") + ": \(authorName)\n"
        output += String(localized: "系列编号") + ": \(seriesId)\n"
        output += String(localized: "包含章节") + ": \(novels.count)\n"
        output += String(localized: "原文链接") + ": https://www.pixiv.net/novel/series/\(seriesId)\n"
        output += "\n"
        output += String(repeating: "=", count: 50)
        output += "\n\n"

        for (index, item) in novels.enumerated() {
            let novel = item.novel
            let content = item.content

            output += String(localized: "第 \(index + 1) 章")
            output += "\n"
            output += "\(novel.title)\n"
            if !content.caption.isEmpty {
                output += "\n"
                output += content.caption.stripHTML()
            }
            output += "\n\n"
            output += content.text.stripHTML()
            output += "\n\n"
            output += String(repeating: "=", count: 50)
            output += "\n\n"
        }

        guard let data = output.data(using: .utf8) else {
            throw NovelExportError.writeFailed("UTF-8 encoding failed")
        }
        return data
    }

    static func buildFilename(novelId: Int, title: String, authorName: String, format: NovelExportFormat, isSeries: Bool = false) -> String {
        let safeTitle = sanitizeFilename(title)
        let safeAuthor = sanitizeFilename(authorName)
        let ext = format.fileExtension

        if isSeries {
            return "\(safeAuthor)_\(safeTitle)_系列.\(ext)"
        }
        return "\(safeAuthor)_\(safeTitle).\(ext)"
    }

    static func sanitizeFilename(_ filename: String) -> String {
        let invalid = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return filename
            .components(separatedBy: invalid)
            .joined(separator: "_")
            .prefix(100)
            .description
    }

    // MARK: - EPUB Export

    static func exportAsEPUB(
        novelId: Int,
        title: String,
        authorName: String,
        coverURL: String?,
        content: NovelReaderContent
    ) async throws -> Data {
        // 1. 构建 manifest
        let manifest = EPUBManifest(
            id: "pixiv-novel-\(novelId)",
            title: title,
            author: authorName,
            language: detectLanguage(content.text),
            modifiedDate: Date(),
            coverImage: coverURL != nil ? "cover.jpg" : nil,
            description: content.caption.stripHTML()
        )

        // 2. 下载封面
        var images: [EPUBImage] = []
        if let coverURL = coverURL ?? content.coverUrl {
            if let cover = try? await EPUBContentBuilder.downloadCover(url: coverURL) {
                images.append(cover)
            }
        }

        // 3. 构建章节
        let chapters = EPUBContentBuilder.buildChapters(from: content)

        // 4. 下载插图
        let illustImages = try await EPUBContentBuilder.downloadImages(from: content)
        images.append(contentsOf: illustImages)

        // 5. 生成 EPUB
        return try await EPUBGenerator.generate(manifest: manifest, chapters: chapters, images: images)
    }

    static func exportSeriesAsEPUB(
        seriesId: Int,
        seriesTitle: String,
        authorName: String,
        novels: [(novel: Novel, content: NovelReaderContent)]
    ) async throws -> Data {
        guard !novels.isEmpty else {
            throw NovelExportError.seriesNotLoaded
        }

        // 1. 构建 manifest
        let manifest = EPUBManifest(
            id: "pixiv-series-\(seriesId)",
            title: seriesTitle,
            author: authorName,
            language: detectLanguage(novels.first?.content.text ?? ""),
            modifiedDate: Date(),
            coverImage: novels.first?.content.coverUrl != nil ? "cover.jpg" : nil,
            description: nil
        )

        // 2. 下载封面（使用第一话封面）
        var images: [EPUBImage] = []
        if let firstNovel = novels.first {
            let coverURL = firstNovel.content.coverUrl ?? firstNovel.novel.imageUrls.medium
            if let cover = try? await EPUBContentBuilder.downloadCover(url: coverURL) {
                images.append(cover)
            }
        }

        // 3. 为每本小说创建一个章节
        var allChapters: [EPUBChapter] = []
        for (index, item) in novels.enumerated() {
            // 每本小说的内容作为一个章节
            let chapterHTML = buildChapterContentFromNovel(item.content)
            let chapter = EPUBChapter(
                id: "chapter-\(String(format: "%03d", index + 1))",
                title: item.novel.title,
                fileName: "chapter-\(String(format: "%03d", index + 1)).xhtml",
                content: chapterHTML,
                order: index + 1
            )
            allChapters.append(chapter)

            // 4. 下载该小说的插图
            let illustImages = try await EPUBContentBuilder.downloadImages(from: item.content)
            images.append(contentsOf: illustImages)
        }

        // 5. 生成 EPUB
        return try await EPUBGenerator.generate(manifest: manifest, chapters: allChapters, images: images)
    }

    private static func buildChapterContentFromNovel(_ content: NovelReaderContent) -> String {
        let chapters = EPUBContentBuilder.buildChapters(from: content)

        // 如果只有一章，直接返回内容
        if chapters.count == 1 {
            return chapters[0].content
        }

        // 多章合并（包含章节标题）
        var allContent: [String] = []
        for chapter in chapters {
            if let title = chapter.title {
                allContent.append("<h2>\(title)</h2>")
            }
            allContent.append(chapter.content)
        }
        return allContent.joined(separator: "\n")
    }

    private static func detectLanguage(_ text: String) -> String {
        // 简单检测：包含日文假名则为日语，否则中文
        let hiragana = text.range(of: "[\u{3040}-\u{309F}]", options: .regularExpression)
        let katakana = text.range(of: "[\u{30A0}-\u{30FF}]", options: .regularExpression)

        if hiragana != nil || katakana != nil {
            return "ja"
        }
        return "zh"
    }
}

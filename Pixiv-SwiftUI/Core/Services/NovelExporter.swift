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
}

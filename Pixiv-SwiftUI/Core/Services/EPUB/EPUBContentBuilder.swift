import Foundation
import Kingfisher

struct EPUBContentBuilder {

    static let defaultCSS = """
    body {
        font-family: -apple-system, "Hiragino Sans", "Noto Sans JP", "Yu Gothic", "Meiryo", sans-serif;
        line-height: 1.8;
        padding: 2em;
        max-width: 40em;
        margin: 0 auto;
        color: #333;
    }
    h1 {
        font-size: 1.5em;
        margin-bottom: 1em;
        text-align: center;
    }
    h2 {
        font-size: 1.3em;
        margin-top: 2em;
        margin-bottom: 1em;
        border-bottom: 1px solid #ccc;
        padding-bottom: 0.3em;
    }
    h3 {
        font-size: 1.1em;
        margin-top: 1.5em;
        margin-bottom: 0.5em;
    }
    img {
        max-width: 100%;
        height: auto;
        display: block;
        margin: 1em auto;
    }
    ruby {
        ruby-align: center;
    }
    rt {
        font-size: 0.5em;
    }
    a {
        color: #0096fa;
        text-decoration: none;
    }
    a:hover {
        text-decoration: underline;
    }
    .caption {
        color: #666;
        font-style: italic;
        margin-bottom: 2em;
        padding: 1em;
        background: #f5f5f5;
        border-left: 3px solid #0096fa;
    }
    .illust-caption {
        text-align: center;
        font-size: 0.9em;
        color: #666;
        margin-top: -0.5em;
        margin-bottom: 1em;
    }
    p {
        margin: 0.8em 0;
        text-indent: 1em;
    }
    .no-indent {
        text-indent: 0;
    }
    """

    static func buildChapters(from content: NovelReaderContent) -> [EPUBChapter] {
        let spans = NovelTextParser.shared.parse(content.text, illusts: content.illusts, images: content.images)

        var chapters: [EPUBChapter] = []
        var currentChapterContent: [String] = []
        var currentChapterTitle: String?
        var currentChapterOrder = 1
        var isFirstContent = true

        for span in spans {
            switch span.type {
            case .chapter:
                if !currentChapterContent.isEmpty {
                    let chapterHTML = buildChapterHTML(content: currentChapterContent, title: currentChapterTitle)
                    let chapter = EPUBChapter(
                        id: "chapter-\(String(format: "%03d", currentChapterOrder))",
                        title: currentChapterTitle,
                        fileName: "chapter-\(String(format: "%03d", currentChapterOrder)).xhtml",
                        content: chapterHTML,
                        order: currentChapterOrder
                    )
                    chapters.append(chapter)
                    currentChapterOrder += 1
                }
                currentChapterTitle = span.content
                currentChapterContent = []
                isFirstContent = true

            case .newPage:
                if !currentChapterContent.isEmpty {
                    let chapterHTML = buildChapterHTML(content: currentChapterContent, title: currentChapterTitle)
                    let chapter = EPUBChapter(
                        id: "chapter-\(String(format: "%03d", currentChapterOrder))",
                        title: currentChapterTitle,
                        fileName: "chapter-\(String(format: "%03d", currentChapterOrder)).xhtml",
                        content: chapterHTML,
                        order: currentChapterOrder
                    )
                    chapters.append(chapter)
                    currentChapterOrder += 1
                }
                currentChapterContent = []
                isFirstContent = true

            case .pixivImage:
                if let metadata = span.metadata,
                   let illustId = metadata["illustId"] as? Int,
                   let targetIndex = metadata["targetIndex"] as? Int {
                    let imageFileName = "illust-\(illustId)-\(targetIndex).jpg"
                    let imgTag = "<img src=\"../images/\(imageFileName)\" alt=\"Illustration\"/>"
                    currentChapterContent.append(imgTag)
                    isFirstContent = false
                }

            case .uploadedImage:
                if let metadata = span.metadata,
                   let imageKey = metadata["imageKey"] as? String {
                    let imageFileName = "upload-\(imageKey).jpg"
                    let imgTag = "<img src=\"../images/\(imageFileName)\" alt=\"Image\"/>"
                    currentChapterContent.append(imgTag)
                    isFirstContent = false
                }

            case .jumpUri:
                if let metadata = span.metadata,
                   let url = metadata["url"] as? String {
                    let title = span.content
                    let linkTag = "<a href=\"\(url)\">\(title)</a>"
                    currentChapterContent.append(linkTag)
                    isFirstContent = false
                }

            case .rubyText:
                if let metadata = span.metadata,
                   let baseText = metadata["baseText"] as? String,
                   let rubyText = metadata["rubyText"] as? String {
                    let rubyTag = "<ruby>\(baseText)<rt>\(rubyText)</rt></ruby>"
                    currentChapterContent.append(rubyTag)
                    isFirstContent = false
                }

            case .normal:
                var text = span.content
                if !text.isEmpty {
                    text = escapeXML(text)
                    if isFirstContent {
                        text = "<p class=\"no-indent\">\(text)</p>"
                    } else {
                        text = "<p>\(text)</p>"
                    }
                    currentChapterContent.append(text)
                    isFirstContent = false
                }
            }
        }

        if !currentChapterContent.isEmpty || chapters.isEmpty {
            let chapterHTML = buildChapterHTML(content: currentChapterContent, title: currentChapterTitle)
            let chapter = EPUBChapter(
                id: "chapter-\(String(format: "%03d", currentChapterOrder))",
                title: currentChapterTitle,
                fileName: "chapter-\(String(format: "%03d", currentChapterOrder)).xhtml",
                content: chapterHTML,
                order: currentChapterOrder
            )
            chapters.append(chapter)
        }

        return chapters
    }

    static func downloadImages(from content: NovelReaderContent) async throws -> [EPUBImage] {
        var images: [EPUBImage] = []

        let illustDict = Dictionary(uniqueKeysWithValues: (content.illusts ?? []).map { ($0.illust.id, $0) })

        let spans = NovelTextParser.shared.parse(content.text, illusts: content.illusts, images: content.images)

        var processedIllusts = Set<Int>()
        var processedUploads = Set<String>()

        for span in spans {
            switch span.type {
            case .pixivImage:
                if let metadata = span.metadata,
                   let illustId = metadata["illustId"] as? Int,
                   let targetIndex = metadata["targetIndex"] as? Int {

                    let uniqueId = illustId * 1000 + targetIndex
                    guard !processedIllusts.contains(uniqueId) else { continue }
                    processedIllusts.insert(uniqueId)

                    if let illustData = illustDict[illustId] {
                        let imageFileName = "illust-\(illustId)-\(targetIndex).jpg"

                        if let imageUrl = getPixivImageURL(from: illustData, page: targetIndex) {
                            do {
                                let imageData = try await downloadImageData(from: imageUrl)
                                let image = EPUBImage(
                                    id: "illust-\(illustId)-\(targetIndex)",
                                    fileName: imageFileName,
                                    mediaType: "image/jpeg",
                                    data: imageData
                                )
                                images.append(image)
                            } catch {
                                print("[EPUBContentBuilder] Failed to download illust \(illustId): \(error)")
                            }
                        }
                    }
                }

            case .uploadedImage:
                if let metadata = span.metadata,
                   let imageKey = metadata["imageKey"] as? String {

                    guard !processedUploads.contains(imageKey) else { continue }
                    processedUploads.insert(imageKey)

                    if let uploadedImage = content.images?.first(where: { $0.urls.original?.contains(imageKey) ?? false }) {
                        let imageFileName = "upload-\(imageKey).jpg"

                        if let imageUrl = uploadedImage.urls.the1200X1200 ?? uploadedImage.urls.original {
                            do {
                                let imageData = try await downloadImageData(from: imageUrl)
                                let image = EPUBImage(
                                    id: "upload-\(imageKey)",
                                    fileName: imageFileName,
                                    mediaType: "image/jpeg",
                                    data: imageData
                                )
                                images.append(image)
                            } catch {
                                print("[EPUBContentBuilder] Failed to download uploaded image \(imageKey): \(error)")
                            }
                        }
                    }
                }

            default:
                break
            }
        }

        return images
    }

    static func downloadCover(url: String) async throws -> EPUBImage? {
        do {
            let imageData = try await downloadImageData(from: url)
            return EPUBImage(
                id: "cover",
                fileName: "cover.jpg",
                mediaType: "image/jpeg",
                data: imageData
            )
        } catch {
            print("[EPUBContentBuilder] Failed to download cover: \(error)")
            return nil
        }
    }

    private static func getPixivImageURL(from illustData: NovelIllustData, page: Int) -> String? {
        // 使用 large 尺寸的图片
        return illustData.illust.imageUrls.large
    }

    private static func downloadImageData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw NovelExportError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("https://www.pixiv.net", forHTTPHeaderField: "Referer")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NovelExportError.writeFailed("Failed to download image")
        }

        return data
    }

    private static func buildChapterHTML(content: [String], title: String?) -> String {
        var html = ""

        if let title = title {
            html += "<h2>\(escapeXML(title))</h2>\n"
        }

        html += content.joined(separator: "\n")

        return html
    }

    private static func escapeXML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

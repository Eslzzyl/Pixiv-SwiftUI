import Foundation
import ZIPFoundation

struct EPUBGenerator {

    static func generate(
        manifest: EPUBManifest,
        chapters: [EPUBChapter],
        images: [EPUBImage]
    ) async throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 1. mimetype (必须未压缩，且在ZIP中第一个)
        let mimetypeURL = tempDir.appendingPathComponent("mimetype")
        try "application/epub+zip".write(to: mimetypeURL, atomically: true, encoding: .utf8)

        // 2. META-INF/container.xml
        let metaDir = tempDir.appendingPathComponent("META-INF")
        try FileManager.default.createDirectory(at: metaDir, withIntermediateDirectories: true)
        let containerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
        """
        try containerXML.write(to: metaDir.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)

        // 3. OEBPS 目录结构
        let oebpsDir = tempDir.appendingPathComponent("OEBPS")
        let textDir = oebpsDir.appendingPathComponent("text")
        let imagesDir = oebpsDir.appendingPathComponent("images")
        let stylesDir = oebpsDir.appendingPathComponent("styles")

        try FileManager.default.createDirectory(at: textDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: stylesDir, withIntermediateDirectories: true)

        // 4. 写入 content.opf
        let opf = buildOPF(manifest: manifest, chapters: chapters, images: images)
        try opf.write(to: oebpsDir.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

        // 5. 写入 nav.xhtml (EPUB 3 导航文档)
        let nav = buildNav(manifest: manifest, chapters: chapters)
        try nav.write(to: oebpsDir.appendingPathComponent("nav.xhtml"), atomically: true, encoding: .utf8)

        // 6. 写入 CSS
        try EPUBContentBuilder.defaultCSS.write(to: stylesDir.appendingPathComponent("style.css"), atomically: true, encoding: .utf8)

        // 7. 写入章节文件
        for chapter in chapters {
            let xhtml = wrapChapter(chapter: chapter, manifest: manifest)
            try xhtml.write(to: textDir.appendingPathComponent(chapter.fileName), atomically: true, encoding: .utf8)
        }

        // 8. 写入图片
        for image in images {
            try image.data.write(to: imagesDir.appendingPathComponent(image.fileName))
        }

        // 9. 打包为 EPUB (ZIP)
        return try await createEPUBArchive(from: tempDir)
    }

    private static func createEPUBArchive(from directory: URL) async throws -> Data {
        let archiveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".epub")
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        // 使用 ZIPFoundation 创建 ZIP
        let archive: Archive
        do {
            archive = try Archive(url: archiveURL, accessMode: .create)
        } catch {
            throw NovelExportError.writeFailed("无法创建 ZIP 归档: \(error.localizedDescription)")
        }

        // 必须先添加 mimetype (未压缩)
        let mimetypeURL = directory.appendingPathComponent("mimetype")
        if let mimetypeData = try? Data(contentsOf: mimetypeURL) {
            let count = UInt32(mimetypeData.count)
            try archive.addEntry(
                with: "mimetype",
                type: .file,
                uncompressedSize: count,
                compressionMethod: .none
            ) { position, size -> Data in
                let start = Int(position)
                let end = Int(position) + Int(size)
                return mimetypeData.subdata(in: start..<end)
            }
        }

        // 添加其他文件
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil)

        while let fileURL = enumerator?.nextObject() as? URL {
            let relativePath = fileURL.path.replacingOccurrences(of: directory.path + "/", with: "")

            // 跳过 mimetype (已添加) 和目录
            if relativePath == "mimetype" { continue }

            let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard !isDirectory else { continue }

            let data = try Data(contentsOf: fileURL)
            let count = UInt32(data.count)

            try archive.addEntry(
                with: relativePath,
                type: .file,
                uncompressedSize: count,
                compressionMethod: .deflate
            ) { position, size -> Data in
                let start = Int(position)
                let end = Int(position) + Int(size)
                return data.subdata(in: start..<end)
            }
        }

        return try Data(contentsOf: archiveURL)
    }

    private static func buildOPF(manifest: EPUBManifest, chapters: [EPUBChapter], images: [EPUBImage]) -> String {
        var manifestItems: [String] = []
        var spineItems: [String] = []

        // 导航文档
        manifestItems.append("<item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\" />")

        // 样式表
        manifestItems.append("<item id=\"style\" href=\"styles/style.css\" media-type=\"text/css\" />")

        // 封面
        if manifest.coverImage != nil {
            manifestItems.append("<item id=\"cover-image\" href=\"images/cover.jpg\" media-type=\"image/jpeg\" properties=\"cover-image\" />")
        }

        // 图片
        for image in images {
            manifestItems.append("<item id=\"\(image.id)\" href=\"images/\(image.fileName)\" media-type=\"\(image.mediaType)\" />")
        }

        // 章节
        for chapter in chapters.sorted(by: { $0.order < $1.order }) {
            manifestItems.append("<item id=\"\(chapter.id)\" href=\"text/\(chapter.fileName)\" media-type=\"application/xhtml+xml\" />")
            spineItems.append("<itemref idref=\"\(chapter.id)\" />")
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package version="3.0" xmlns="http://www.idpf.org/2007/opf" xml:lang="\(manifest.language)">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id=\"bookid\">\(manifest.id)</dc:identifier>
                <dc:title>\(escapeXML(manifest.title))</dc:title>
                <dc:creator>\(escapeXML(manifest.author))</dc:creator>
                <dc:language>\(manifest.language)</dc:language>
                <dc:description>\(manifest.description.map(escapeXML) ?? "")</dc:description>
                <meta property=\"dcterms:modified\">\(manifest.modifiedDateISO8601)</meta>
            </metadata>
            <manifest>
                \(manifestItems.joined(separator: "\n                "))
            </manifest>
            <spine>
                \(spineItems.joined(separator: "\n                "))
            </spine>
        </package>
        """
    }

    private static func buildNav(manifest: EPUBManifest, chapters: [EPUBChapter]) -> String {
        var navItems: [String] = []

        for chapter in chapters.sorted(by: { $0.order < $1.order }) {
            let title = chapter.title ?? "Chapter \(chapter.order)"
            navItems.append("<li><a href=\"text/\(chapter.fileName)\">\(escapeXML(title))</a></li>")
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="\(manifest.language)">
        <head>
            <meta charset="UTF-8"/>
            <title>\(escapeXML(manifest.title))</title>
            <link rel=\"stylesheet\" type=\"text/css\" href=\"styles/style.css\"/>
        </head>
        <body>
            <nav epub:type=\"toc\" id=\"toc\">
                <h1>\(escapeXML(manifest.title))</h1>
                <ol>
                    \(navItems.joined(separator: "\n                    "))
                </ol>
            </nav>
        </body>
        </html>
        """
    }

    private static func wrapChapter(chapter: EPUBChapter, manifest: EPUBManifest) -> String {
        let title = chapter.title ?? manifest.title

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="\(manifest.language)">
        <head>
            <meta charset="UTF-8"/>
            <title>\(escapeXML(title))</title>
            <link rel=\"stylesheet\" type=\"text/css\" href=\"../styles/style.css\"/>
        </head>
        <body>
            \(chapter.content)
        </body>
        </html>
        """
    }

    private static func escapeXML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageMetadataProcessor {
    /// 注入元数据到图片数据中
    /// - Parameters:
    ///   - data: 原始图片数据
    ///   - task: 下载任务信息
    ///   - pageIndex: 当前页码（从0开始）
    /// - Returns: 处理后的图片数据
    static func inject(data: Data, task: DownloadTask, pageIndex: Int? = nil) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let uti = CGImageSourceGetType(source) else {
            return data
        }

        let metadata = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(metadata as CFMutableData, uti, 1, nil) else {
            return data
        }

        // 获取原始属性
        var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]

        // 构造 IPTC 和 EXIF 字典
        var iptc: [CFString: Any] = (properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any]) ?? [:]
        var exif: [CFString: Any] = (properties[kCGImagePropertyExifDictionary] as? [CFString: Any]) ?? [:]

        // 设置标题 (ObjectName)
        iptc[kCGImagePropertyIPTCObjectName] = task.title as CFString

        // 设置作者 (Byline)
        iptc[kCGImagePropertyIPTCByline] = task.authorName as CFString

        // 设置 PID (SpecialInstructions)
        iptc[kCGImagePropertyIPTCSpecialInstructions] = "PID: \(task.illustId)" as CFString

        if let taskMetadata = task.metadata {
            // 设置简介 (Caption/Abstract)
            var caption = taskMetadata.caption
            if let page = pageIndex {
                caption += "\n\nPage: \(page + 1) / \(task.pageCount)"
            }
            iptc[kCGImagePropertyIPTCCaptionAbstract] = caption as CFString

            // 设置标签 (Keywords)
            let keywords = taskMetadata.tags
            iptc[kCGImagePropertyIPTCKeywords] = keywords as CFArray

            // 处理日期和时间：转换为本地时区以获得最佳兼容性
            let isoFormatter = ISO8601DateFormatter()
            if let date = isoFormatter.date(from: taskMetadata.createDate) {
                // IPTC 日期格式: YYYYMMDD
                let iptcDateFormatter = DateFormatter()
                iptcDateFormatter.dateFormat = "yyyyMMdd"
                iptcDateFormatter.timeZone = .current
                iptc[kCGImagePropertyIPTCDateCreated] = iptcDateFormatter.string(from: date) as CFString

                // IPTC 时间格式: HHMMSS±HHMM
                let iptcTimeFormatter = DateFormatter()
                iptcTimeFormatter.dateFormat = "HHmmssZZZZZ"
                iptcTimeFormatter.timeZone = .current
                let timeString = iptcTimeFormatter.string(from: date).replacingOccurrences(of: ":", with: "")
                iptc[kCGImagePropertyIPTCTimeCreated] = timeString as CFString

                // EXIF 拍摄日期格式: yyyy:MM:dd HH:mm:ss
                let exifDateFormatter = DateFormatter()
                exifDateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                exifDateFormatter.timeZone = .current
                let exifDateString = exifDateFormatter.string(from: date)
                exif[kCGImagePropertyExifDateTimeOriginal] = exifDateString as CFString
                exif[kCGImagePropertyExifDateTimeDigitized] = exifDateString as CFString
            }
        }

        // 处理 GIF 特殊逻辑 (Comment Extension)
        if uti == UTType.gif.identifier as CFString {
            var gifProps = (properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]) ?? [:]

            var commentDict: [String: Any] = [
                "pid": task.illustId,
                "title": task.title,
                "author": task.authorName
            ]
            if let taskMetadata = task.metadata {
                commentDict["caption"] = taskMetadata.caption
                commentDict["tags"] = taskMetadata.tags
            }

            if let jsonData = try? JSONSerialization.data(withJSONObject: commentDict, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                // kCGImagePropertyGIFComments 在某些 SDK 版本中可能未公开，使用字符串字面量
                let kGIFComments = "Comments" as CFString
                gifProps[kGIFComments] = "Pixiv Metadata: \(jsonString)" as CFString
            }
            properties[kCGImagePropertyGIFDictionary] = gifProps as CFDictionary
        }

        properties[kCGImagePropertyIPTCDictionary] = iptc as CFDictionary
        properties[kCGImagePropertyExifDictionary] = exif as CFDictionary

        // 写入到目的地
        CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
        if CGImageDestinationFinalize(destination) {
            return metadata as Data
        }

        return data
    }
}

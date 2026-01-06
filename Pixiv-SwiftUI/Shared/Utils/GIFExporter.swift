import Foundation
import ImageIO
import UniformTypeIdentifiers
import Kingfisher

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

private func imageToJpegData(_ image: KFCrossPlatformImage) -> Data? {
    #if canImport(UIKit)
    return image.jpegData(compressionQuality: 0.9)
    #else
    guard let cgImage = image.cgImage else { return nil }
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    return bitmap.representation(forType: .jpeg, properties: [.compressionFactor: 0.9])
    #endif
}

struct GIFExporter {
    static func export(
        frameURLs: [URL],
        delays: [TimeInterval],
        outputURL: URL,
        loopCount: Int = 0
    ) async throws {
        guard frameURLs.count == delays.count else {
            throw GIFExportError.frameCountMismatch
        }
        
        guard frameURLs.count > 0 else {
            throw GIFExportError.noFrames
        }
        
        try? FileManager.default.removeItem(at: outputURL)
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // 处理帧数据并统计成功数量
        var processedFrames: [(CGImage, TimeInterval)] = []
        var failedFrames = 0
        
        for (index, url) in frameURLs.enumerated() {
            do {
                let imageData = try getImageData(from: url)
                guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
                    throw GIFExportError.imageLoadFailed
                }
                
                guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    throw GIFExportError.imageLoadFailed
                }
                
                let delay = delays[index]
                processedFrames.append((cgImage, delay))
                
            } catch {
                failedFrames += 1
                print("[GIFExporter] 帧 \(index) 处理失败: \(error)")
            }
        }
        
        guard !processedFrames.isEmpty else {
            throw GIFExportError.allFramesFailed
        }
        
        print("[GIFExporter] 成功处理 \(processedFrames.count) 帧，失败 \(failedFrames) 帧")
        
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            processedFrames.count,
            nil
        ) else {
            throw GIFExportError.creationFailed
        }
        
        let gifProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: loopCount
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
        
        for (cgImage, delay) in processedFrames {
            let frameProperties: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: delay
                ]
            ]
            
            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
        }
        
        guard CGImageDestinationFinalize(destination) else {
            throw GIFExportError.finalizationFailed
        }
        
        print("[GIFExporter] GIF 导出成功: \(outputURL)")
    }
    
    private static func getImageData(from url: URL) throws -> Data {
        if url.scheme == "kingfisher" {
            // 从Kingfisher缓存获取图片
            if let cachedImage = ImageCache.default.retrieveImageInMemoryCache(forKey: url.absoluteString),
               let data = imageToJpegData(cachedImage) {
                return data
            }
            
            // 如果内存缓存没有，尝试磁盘缓存
            let fileURL = ImageCache.default.diskStorage.cacheFileURL(forKey: url.absoluteString)
            do {
                return try Data(contentsOf: fileURL)
            } catch {
                print("[GIFExporter] 从磁盘缓存读取失败: \(error)")
                throw GIFExportError.imageLoadFailed
            }
        } else {
            // 原有文件URL处理
            return try Data(contentsOf: url)
        }
    }
}

enum GIFExportError: LocalizedError {
    case frameCountMismatch
    case noFrames
    case creationFailed
    case finalizationFailed
    case imageLoadFailed
    case allFramesFailed
    
    var errorDescription: String? {
        switch self {
        case .frameCountMismatch:
            return "帧数量不匹配"
        case .noFrames:
            return "没有可导出的帧"
        case .creationFailed:
            return "GIF 创建失败"
        case .finalizationFailed:
            return "GIF 生成失败"
        case .imageLoadFailed:
            return "图片加载失败"
        case .allFramesFailed:
            return "所有帧处理失败"
        }
    }
}

import Foundation
import ImageIO
import UniformTypeIdentifiers
import Kingfisher

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

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
        
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            frameURLs.count,
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
        
        for (index, url) in frameURLs.enumerated() {
            let imageData = try Data(contentsOf: url)
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
                continue
            }
            
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                continue
            }
            
            let delay = delays[index]
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
    }
}

enum GIFExportError: LocalizedError {
    case frameCountMismatch
    case noFrames
    case creationFailed
    case finalizationFailed
    
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
        }
    }
}

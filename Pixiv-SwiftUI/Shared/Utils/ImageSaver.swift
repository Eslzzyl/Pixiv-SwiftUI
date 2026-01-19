import Foundation
#if os(iOS)
import UIKit
import Photos
#else
import AppKit
#endif

enum ImageSaverError: LocalizedError {
    case permissionDenied
    case invalidData
    case writeFailed(String)
    case downloadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "没有相册访问权限，请在设置中允许访问"
        case .invalidData:
            return "图片数据无效"
        case .writeFailed(let message):
            return "保存失败: \(message)"
        case .downloadFailed(let message):
            return "下载失败: \(message)"
        }
    }
}

struct ImageSaver {
    
    static func saveToPhotosAlbum(data: Data) async throws {
        #if os(iOS)
        print("[ImageSaver] 开始保存到相册，数据大小: \(data.count) bytes")
        
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        print("[ImageSaver] 相册权限状态: \(status.rawValue)")
        
        switch status {
        case .authorized, .limited:
            break
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            print("[ImageSaver] 请求权限后状态: \(newStatus.rawValue)")
            if newStatus != .authorized && newStatus != .limited {
                throw ImageSaverError.permissionDenied
            }
        case .denied, .restricted:
            throw ImageSaverError.permissionDenied
        @unknown default:
            throw ImageSaverError.permissionDenied
        }
        
        guard let uiImage = UIImage(data: data) else {
            print("[ImageSaver] 错误: 无法将 Data 转换为 UIImage，数据大小: \(data.count)")
            throw ImageSaverError.invalidData
        }
        print("[ImageSaver] UIImage 创建成功: \(uiImage.size.width)x\(uiImage.size.height)")
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
        }
        print("[ImageSaver] 保存到相册成功")
        #else
        throw ImageSaverError.permissionDenied
        #endif
    }
    
    static func saveToFile(data: Data, url: URL, filename: String? = nil) async throws {
        let saveURL: URL
        if let customURL = url as URL?, !customURL.hasDirectoryPath {
            saveURL = customURL
        } else {
            let finalFilename = filename ?? "image_\(Date().timeIntervalSince1970).jpg"
            saveURL = url.appendingPathComponent(finalFilename)
        }
        
        try data.write(to: saveURL)
    }
    
    static func createZip(from files: [URL], outputURL: URL) async throws {
        #if os(macOS)
        try? FileManager.default.removeItem(at: outputURL)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-j", outputURL.path] + files.map { $0.path }
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw ImageSaverError.writeFailed("zip 进程返回错误")
        }
        #else
        throw ImageSaverError.writeFailed("ZIP 创建仅在 macOS 支持")
        #endif
    }
    
    static func downloadImage(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            print("[ImageSaver] 无效的 URL: \(urlString)")
            throw ImageSaverError.downloadFailed("无效的 URL")
        }
        
        print("[ImageSaver] 开始下载: \(url.lastPathComponent)")
        
        var headers: [String: String] = [:]
        if let modifiedRequest = PixivImageLoader.shared.modified(for: URLRequest(url: url)) {
            headers = modifiedRequest.allHTTPHeaderFields ?? [:]
        }
        
        let (tempURL, response) = try await NetworkClient.shared.download(from: url, headers: headers)
        let data = try Data(contentsOf: tempURL)
        try? FileManager.default.removeItem(at: tempURL)
        
        print("[ImageSaver] 下载完成，数据大小: \(data.count) bytes")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[ImageSaver] 错误: 无效的 HTTP 响应")
            throw ImageSaverError.downloadFailed("无效的 HTTP 响应")
        }
        
        print("[ImageSaver] HTTP 状态码: \(httpResponse.statusCode), Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "nil")")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("[ImageSaver] 错误: HTTP 状态码异常 \(httpResponse.statusCode)")
            throw ImageSaverError.downloadFailed("HTTP 错误: \(httpResponse.statusCode)")
        }
        
        guard !data.isEmpty else {
            print("[ImageSaver] 错误: 返回数据为空")
            throw ImageSaverError.downloadFailed("返回数据为空")
        }
        
        return data
    }
    
    static func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return filename
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .prefix(200)
            .description
    }
}

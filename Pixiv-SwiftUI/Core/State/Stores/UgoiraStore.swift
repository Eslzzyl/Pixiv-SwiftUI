import Foundation
import Combine
import zlib
import Kingfisher
#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum UgoiraStatus: Equatable {
    case idle
    case downloading(progress: Double)
    case unzipping
    case ready
    case playing
    case error(String)
    
    static func == (lhs: UgoiraStatus, rhs: UgoiraStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.downloading(let p1), .downloading(let p2)):
            return p1 == p2
        case (.unzipping, .unzipping):
            return true
        case (.ready, .ready):
            return true
        case (.playing, .playing):
            return true
        case (.error(let s1), .error(let s2)):
            return s1 == s2
        default:
            return false
        }
    }
}

@MainActor
final class UgoiraStore: ObservableObject {
    let illustId: Int
    let expiration: CacheExpiration
    
    @Published var status: UgoiraStatus = .idle
    @Published var metadata: UgoiraMetadata?
    @Published var frameURLs: [URL] = []
    @Published var frameDelays: [TimeInterval] = []
    
    private var downloadTask: Task<Void, Never>?
    private let temporaryDir: URL
    private let cache: ImageCache
    
    init(illustId: Int, expiration: CacheExpiration = .hours(1)) {
        self.illustId = illustId
        self.expiration = expiration
        self.cache = ImageCache.default
        self.temporaryDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Ugoira_\(illustId)_\(UUID().uuidString)", isDirectory: true)
    }
    
    var isReady: Bool {
        status == .ready || status == .playing
    }
    
    func loadIfNeeded() async {
        guard status == .idle else { return }
        await loadMetadata()
    }
    
    func loadMetadata() async {
        status = .idle
        print("[UgoiraStore] loadMetadata() 开始加载 illustId=\(illustId)")
        
        do {
            let response = try await PixivAPI.shared.getUgoiraMetadata(illustId: illustId)
            print("[UgoiraStore] API 请求成功，frames.count=\(response.ugoiraMetadata.frames.count)")
            self.metadata = response.ugoiraMetadata
            self.frameDelays = response.ugoiraMetadata.frames.map { $0.delayTimeInterval }
            
            let framesExist = await checkFramesExist()
            print("[UgoiraStore] checkFramesExist()=\(framesExist)，frameURLs.count=\(frameURLs.count)")
            
            if framesExist {
                status = .ready
                print("[UgoiraStore] 状态设置为 .ready")
            } else {
                print("[UgoiraStore] 帧不存在，需要下载")
            }
        } catch {
            print("[UgoiraStore] API 请求失败: \(error.localizedDescription)")
            status = .error(error.localizedDescription)
        }
    }
    
    func startDownload() async {
        print("[UgoiraStore] startDownload() illustId=\(illustId)")
        
        let metadata: UgoiraMetadata
        if let existingMetadata = self.metadata {
            print("[UgoiraStore] 使用已有的 metadata")
            metadata = existingMetadata
        } else {
            print("[UgoiraStore] 没有 metadata，先调用 loadMetadata()")
            await loadMetadata()
            guard let fetchedMetadata = self.metadata else {
                print("[UgoiraStore] loadMetadata 后 metadata 仍为 nil，返回")
                return
            }
            metadata = fetchedMetadata
        }
        
        status = .downloading(progress: 0)
        print("[UgoiraStore] 开始下载，zipURL=\(metadata.zipUrls.medium)")
        
        let zipURL = metadata.zipUrls.medium
        // 修改：将 zip 文件下载到系统临时目录，而不是解压目录，防止被 unzip 清理掉
        let zipFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("ugoira_\(illustId)_\(UUID().uuidString).zip")
        
        do {
            print("[UgoiraStore] 调用 downloadZip...")
            try await downloadZip(from: zipURL, to: zipFileURL)
            status = .unzipping
            print("[UgoiraStore] 下载完成，开始解压...")
            try await unzip(at: zipFileURL)
            
            // 清理 zip 文件
            try? FileManager.default.removeItem(at: zipFileURL)
            
            status = .ready
            print("[UgoiraStore] 解压并缓存完成，状态设置为 .ready，frameURLs.count=\(frameURLs.count)")
        } catch {
            print("[UgoiraStore] 错误: \(error.localizedDescription)")
            status = .error(error.localizedDescription)
        }
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        status = .idle
    }
    
    private func downloadZip(from remoteURL: String, to localURL: URL) async throws {
        print("[UgoiraStore] downloadZip: remoteURL=\(remoteURL)")
        guard let url = URL(string: remoteURL) else {
            print("[UgoiraStore] 无效的 URL")
            throw UgoiraError.invalidURL
        }
        
        try? FileManager.default.removeItem(at: localURL)
        try FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        print("[UgoiraStore] 开始下载...")
        
        var request = URLRequest(url: url)
        PixivImageLoader.shared.modified(for: request).map { request = $0 }
        
        let (tempURL, response) = try await downloadWithProgress(request: request)
        print("[UgoiraStore] 下载响应: \(response)")
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("[UgoiraStore] HTTP 错误，statusCode=\((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw UgoiraError.downloadFailed
        }
        
        try FileManager.default.moveItem(at: tempURL, to: localURL)
        print("[UgoiraStore] ZIP 文件保存到: \(localURL)")
    }
    
    private func downloadWithProgress(request: URLRequest) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: request) { tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let tempURL = tempURL, let response = response else {
                    continuation.resume(throwing: UgoiraError.downloadFailed)
                    return
                }
                continuation.resume(returning: (tempURL, response))
            }
            
            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                Task { @MainActor in
                    self.status = .downloading(progress: progress.fractionCompleted)
                }
            }
            
            task.resume()
            
            _ = observation
        }
    }
    
    private func unzip(at zipURL: URL) async throws {
        print("[UgoiraStore] unzip: zipURL=\(zipURL)")
        let extractionURL = temporaryDir
        print("[UgoiraStore] 解压目标目录: \(extractionURL)")
        
        try? FileManager.default.removeItem(at: extractionURL)
        try FileManager.default.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        
        #if os(macOS)
        print("[UgoiraStore] 使用 macOS unzip 方式")
        try await unzipWithProcess(url: zipURL, to: extractionURL)
        #else
        print("[UgoiraStore] 使用 iOS Data unzip 方式")
        try await unzipWithData(url: zipURL, to: extractionURL)
        #endif
        
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: extractionURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: .skipsHiddenFiles
        )
        print("[UgoiraStore] 解压后目录内容: \(contents.count) 个文件")
        
        // 收集文件并存入 Kingfisher
        var frameURLs: [URL] = []
        let sortedContents = contents.filter {
            $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "jpeg"
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        print("[UgoiraStore] 找到帧文件: \(sortedContents.count) 个，开始存入 Kingfisher")
        
        for (index, fileURL) in sortedContents.enumerated() {
            let key = frameKey(for: illustId, frameIndex: index)
            let cacheKey = "kingfisher://\(key)"
            if let data = try? Data(contentsOf: fileURL), let image = KFCrossPlatformImage(data: data) {
                // 存入 Kingfisher 缓存 (内存 + 磁盘)
                // Kingfisher 的 store 方法可能是 async throws 的
                try? await cache.store(image, original: data, forKey: cacheKey)
                frameURLs.append(URL(string: cacheKey)!)
            } else {
                print("[UgoiraStore] 读取文件或创建图片失败: \(fileURL)")
            }
        }
        
        self.frameURLs = frameURLs
        
        // 清理临时解压目录
        try? FileManager.default.removeItem(at: extractionURL)
        print("[UgoiraStore] 已清理临时解压目录")
    }
    
    #if os(macOS)
    private func unzipWithProcess(url: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", url.path, "-d", destination.path]
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: UgoiraError.unzipFailed)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    #endif
    
    #if os(iOS)
    private func unzipWithData(url: URL, to destination: URL) async throws {
        print("[UgoiraStore] unzipWithData: url=\(url)")
        let zipData = try Data(contentsOf: url)
        print("[UgoiraStore] ZIP 数据大小: \(zipData.count) bytes")
        try extractZipData(zipData, to: destination)
    }
    
    private func extractZipData(_ data: Data, to destination: URL) throws {
        print("[UgoiraStore] 开始解析 ZIP 数据")
        var offset = 0
        var extractedCount = 0
        var errorCount = 0
        
        while offset < data.count {
            let header = data.subdata(in: offset..<(offset + 30))
            let headerBytes = [UInt8](header)
            
            guard headerBytes[0] == 0x50 && headerBytes[1] == 0x4B && 
                  (headerBytes[2] == 0x03 || headerBytes[2] == 0x05) else {
                print("[UgoiraStore] ZIP 解析在 offset=\(offset) 处遇到无效头部")
                break
            }
            
            let compressionMethod = UInt16(headerBytes[8..<10].reversed().reduce(0) { ($0 << 8) + Int($1) })
            let compressedSize = UInt32(headerBytes[18..<22].reversed().reduce(0) { ($0 << 8) + Int($1) })
            let uncompressedSize = UInt32(headerBytes[22..<26].reversed().reduce(0) { ($0 << 8) + Int($1) })
            let fileNameLength = UInt16(headerBytes[26..<28].reversed().reduce(0) { ($0 << 8) + Int($1) })
            let extraFieldLength = UInt16(headerBytes[28..<30].reversed().reduce(0) { ($0 << 8) + Int($1) })
            
            let fileNameStart = offset + 30
            let fileNameEnd = fileNameStart + Int(fileNameLength)
            let extraStart = fileNameEnd
            let extraEnd = extraStart + Int(extraFieldLength)
            let dataStart = extraEnd
            let dataEnd = dataStart + Int(compressedSize)
            
            let fileNameData = data.subdata(in: fileNameStart..<fileNameEnd)
            let fileName = String(data: fileNameData, encoding: .utf8) ?? ""
            
            guard !fileName.isEmpty else {
                print("[UgoiraStore] 文件名为空，停止解析")
                break
            }
            
            print("[UgoiraStore] 解析文件: \(fileName), compression=\(compressionMethod), size=\(compressedSize)")
            
            let fileURL = destination.appendingPathComponent(fileName)
            let fileDir = fileURL.deletingLastPathComponent()
            
            if !FileManager.default.fileExists(atPath: fileDir.path) {
                try FileManager.default.createDirectory(at: fileDir, withIntermediateDirectories: true)
            }
            
            if compressionMethod == 0 {
                let fileData = data.subdata(in: dataStart..<dataEnd)
                try fileData.write(to: fileURL)
                extractedCount += 1
                print("[UgoiraStore] 成功提取: \(fileName)")
            } else if compressionMethod == 8 {
                print("[UgoiraStore] 使用 Deflate 解压: \(fileName)")
                let compressedData = data.subdata(in: dataStart..<dataEnd)
                if let decompressedData = try? decompressDeflate(compressedData, size: Int(uncompressedSize)) {
                    try decompressedData.write(to: fileURL)
                    extractedCount += 1
                    print("[UgoiraStore] 成功提取 (Deflate): \(fileName)")
                } else {
                    errorCount += 1
                    print("[UgoiraStore] Deflate 解压失败: \(fileName)")
                }
            } else {
                errorCount += 1
                print("[UgoiraStore] 不支持的压缩方法: \(compressionMethod)")
            }
            
            offset = dataEnd
        }
        
        print("[UgoiraStore] ZIP 解析完成，共提取 \(extractedCount) 个文件，失败 \(errorCount) 个")
    }
    
    private func decompressDeflate(_ data: Data, size: Int) throws -> Data {
        var stream = z_stream()
        stream.zalloc = nil
        stream.zfree = nil
        stream.opaque = nil
        
        let status = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        if status != Z_OK {
            throw UgoiraError.unzipFailed
        }
        
        defer { inflateEnd(&stream) }
        
        let inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        defer { inputBuffer.deallocate() }
        data.copyBytes(to: inputBuffer, count: data.count)
        
        stream.next_in = inputBuffer
        stream.avail_in = UInt32(data.count)
        
        let outputBuffer = UnsafeMutablePointer<Bytef>.allocate(capacity: size)
        defer { outputBuffer.deallocate() }
        
        stream.next_out = outputBuffer
        stream.avail_out = UInt32(size)
        
        let inflateStatus = inflate(&stream, Z_NO_FLUSH)
        
        if inflateStatus == Z_OK || inflateStatus == Z_STREAM_END {
            let actualSize = Int(stream.total_out)
            return Data(bytes: outputBuffer, count: actualSize)
        } else {
            throw UgoiraError.unzipFailed
        }
    }
    #endif
    
    private func checkFramesExist() async -> Bool {
        guard let frameCount = metadata?.frames.count, frameCount > 0 else {
            return false
        }
        
        var existingFrames: [URL] = []
        
        for index in 0..<frameCount {
            let key = frameKey(for: illustId, frameIndex: index)
            let cacheKey = "kingfisher://\(key)"
            if cache.isCached(forKey: cacheKey) {
                existingFrames.append(URL(string: cacheKey)!)
            }
        }
        
        if existingFrames.count == frameCount {
            self.frameURLs = existingFrames.sorted {
                $0.lastPathComponent < $1.lastPathComponent
            }
            return true
        }
        
        return false
    }
    
    private func frameKey(for illustId: Int, frameIndex: Int) -> String {
        return "ugoira_\(illustId)_frame_\(frameIndex)"
    }
    
    func cleanup() {
        Task {
            await clearCache()
        }
        status = .idle
    }
    
    func clearCache() async {
        cache.clearMemoryCache()
        await cache.clearDiskCache()
        try? FileManager.default.removeItem(at: temporaryDir)
    }
    
    static func cleanupLegacyCache() {
        let legacyCacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ugoira", isDirectory: true)
        try? FileManager.default.removeItem(at: legacyCacheDir)
    }
}

enum UgoiraError: LocalizedError {
    case invalidURL
    case downloadFailed
    case unzipFailed
    case frameNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .downloadFailed:
            return "下载失败"
        case .unzipFailed:
            return "解压失败"
        case .frameNotFound:
            return "帧文件不存在"
        }
    }
}

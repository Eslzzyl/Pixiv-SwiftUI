import SwiftUI
import Kingfisher

#if os(iOS)
import UIKit
#endif

struct UgoiraView: View {
    let frameURLs: [URL]
    let frameDelays: [TimeInterval]
    let aspectRatio: CGFloat
    let expiration: CacheExpiration
    
    @State private var currentFrameIndex: Int = 0
    @State private var displayLink: CADisplayLink?
    @State private var lastFrameTime: CFTimeInterval = 0
    @State private var accumulatedTime: CFTimeInterval = 0
    @State private var animationTimer: Timer?
    @State private var isReady: Bool = false
    @State private var preloadTask: Task<Void, Never>?
    
    init(frameURLs: [URL], frameDelays: [TimeInterval], aspectRatio: CGFloat, expiration: CacheExpiration = .hours(1)) {
        self.frameURLs = frameURLs
        self.frameDelays = frameDelays
        self.aspectRatio = aspectRatio
        self.expiration = expiration
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if !frameURLs.isEmpty {
                    currentFrameImage
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    ProgressView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .onAppear {
            preloadAndPlay()
        }
        .onDisappear {
            stopPlayback()
            preloadTask?.cancel()
        }
    }
    
    @ViewBuilder
    private var currentFrameImage: some View {
        let index = currentFrameIndex
        if index < frameURLs.count {
            KFImage(frameURLs[index])
                .cacheOriginalImage()
                .resizable()
                .scaledToFill()
        }
    }
    
    private func preloadAndPlay() {
        preloadTask?.cancel()
        preloadTask = Task {
            await preloadFrames()
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                isReady = true
                startPlayback()
            }
        }
    }
    
    private func preloadFrames() async {
        guard !frameURLs.isEmpty else { return }
        
        let options: KingfisherOptionsInfo = [
            .requestModifier(PixivImageLoader.shared),
            .cacheOriginalImage,
            .diskCacheExpiration(expiration.kingfisherExpiration),
            .memoryCacheExpiration(expiration.kingfisherExpiration)
        ]
        
        await withTaskGroup(of: Void.self) { group in
            for url in frameURLs {
                group.addTask {
                    _ = try? await KingfisherManager.shared.retrieveImage(with: url, options: options)
                }
            }
        }
    }
    
    private func startPlayback() {
        guard !frameURLs.isEmpty else { return }
        
        #if os(iOS)
        displayLink = CADisplayLink(target: DisplayLinkTarget { [self] timestamp in
            updateFrame(at: timestamp)
        }, selector: #selector(DisplayLinkTarget.handleDisplayLink(_:)))
        displayLink?.add(to: .main, forMode: .common)
        #else
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            updateFrameWithTimer()
        }
        #endif
    }
    
    private func stopPlayback() {
        displayLink?.invalidate()
        displayLink = nil
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    #if os(iOS)
    private func updateFrame(at timestamp: CFTimeInterval) {
        if lastFrameTime == 0 {
            lastFrameTime = timestamp
            return
        }
        
        let frameDuration = frameDelays[currentFrameIndex]
        let deltaTime = timestamp - lastFrameTime
        accumulatedTime += deltaTime
        
        if accumulatedTime >= frameDuration {
            accumulatedTime = 0
            currentFrameIndex += 1
            if currentFrameIndex >= frameURLs.count {
                currentFrameIndex = 0
            }
        }
        
        lastFrameTime = timestamp
    }
    #else
    private func updateFrameWithTimer() {
        let frameDuration = frameDelays[currentFrameIndex]
        accumulatedTime += 1.0/60.0
        
        if accumulatedTime >= frameDuration {
            accumulatedTime = 0
            currentFrameIndex += 1
            if currentFrameIndex >= frameURLs.count {
                currentFrameIndex = 0
            }
        }
    }
    #endif
}

#if os(iOS)
private final class DisplayLinkTarget {
    private let callback: (CFTimeInterval) -> Void
    
    init(callback: @escaping (CFTimeInterval) -> Void) {
        self.callback = callback
    }
    
    @objc func handleDisplayLink(_ displayLink: CADisplayLink) {
        callback(displayLink.timestamp)
    }
}
#endif

#Preview {
    UgoiraView(
        frameURLs: [],
        frameDelays: [0.1, 0.1, 0.1],
        aspectRatio: 1.5
    )
    .frame(width: 300, height: 200)
}

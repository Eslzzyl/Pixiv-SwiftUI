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
    let shouldAutoPlay: Bool
    @Binding var isPlaying: Bool

    @State private var currentFrameIndex: Int = 0
    @State private var displayLink: CADisplayLink?
    @State private var lastFrameTime: CFTimeInterval = 0
    @State private var accumulatedTime: CFTimeInterval = 0
    @State private var animationTimer: Timer?
    @State private var isReady: Bool = false
    @State private var preloadTask: Task<Void, Never>?

    init(frameURLs: [URL], frameDelays: [TimeInterval], aspectRatio: CGFloat, expiration: CacheExpiration = .hours(1), shouldAutoPlay: Bool = true, isPlaying: Binding<Bool> = .constant(false)) {
        self.frameURLs = frameURLs
        self.frameDelays = frameDelays
        self.aspectRatio = aspectRatio
        self.expiration = expiration
        self.shouldAutoPlay = shouldAutoPlay
        self._isPlaying = isPlaying
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
            if shouldAutoPlay && !isPlaying {
                preloadAndPlay()
            }
        }
        .onChange(of: isPlaying) { _, newValue in
            if newValue && !isReady {
                preloadAndPlay()
            } else if newValue && isReady {
                startPlayback()
            } else if !newValue && isReady {
                stopPlayback()
            }
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
                .scaledToFit()
        }
    }

    private func preloadAndPlay() {
        preloadTask?.cancel()
        preloadTask = Task {
            await preloadFrames()

            guard !Task.isCancelled else { return }

            await MainActor.run {
                isReady = true
                isPlaying = true
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
                let source: Source = shouldUseDirectConnection(url: url)
                    ? .directNetwork(url)
                    : .network(url)

                group.addTask {
                    _ = try? await KingfisherManager.shared.retrieveImage(with: source, options: options)
                }
            }
        }
    }

    private func shouldUseDirectConnection(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return NetworkModeStore.shared.useDirectConnection &&
               (host.contains("i.pximg.net") || host.contains("img-master.pixiv.net"))
    }

    private func startPlayback() {
        guard !frameURLs.isEmpty else { return }
        isPlaying = true

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
        isPlaying = false
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

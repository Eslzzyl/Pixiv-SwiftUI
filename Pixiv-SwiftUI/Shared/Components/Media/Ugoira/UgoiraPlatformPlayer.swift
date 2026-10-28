import SwiftUI
import Kingfisher

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct UgoiraPlatformPlayer: View {
    let frames: [KFCrossPlatformImage]
    let frameDelays: [TimeInterval]
    let isPlaying: Bool

    var body: some View {
        #if os(iOS)
        UgoiraUIKitPlayer(
            frames: frames,
            frameDelays: frameDelays,
            isPlaying: isPlaying
        )
        #else
        UgoiraAppKitPlayer(
            frames: frames,
            frameDelays: frameDelays,
            isPlaying: isPlaying
        )
        #endif
    }
}

#if os(iOS)
private struct UgoiraUIKitPlayer: UIViewRepresentable {
    let frames: [UIImage]
    let frameDelays: [TimeInterval]
    let isPlaying: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        context.coordinator.imageView = imageView
        context.coordinator.update(frames: frames, delays: frameDelays)
        context.coordinator.setPlaying(isPlaying)
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        context.coordinator.imageView = imageView
        context.coordinator.update(frames: frames, delays: frameDelays)
        context.coordinator.setPlaying(isPlaying)
    }

    static func dismantleUIView(_ imageView: UIImageView, coordinator: Coordinator) {
        coordinator.stopPlayback()
        coordinator.imageView = nil
    }

    final class Coordinator: NSObject {
        weak var imageView: UIImageView?
        private var frames: [UIImage] = []
        private var delays: [TimeInterval] = []
        private var currentFrameIndex = 0
        private var lastFrameTime: CFTimeInterval = 0
        private var accumulatedTime: CFTimeInterval = 0
        private var displayLink: CADisplayLink?

        func update(frames: [UIImage], delays: [TimeInterval]) {
            guard self.frames.count != frames.count || self.frames.first !== frames.first else {
                return
            }

            stopPlayback()
            self.frames = frames
            self.delays = delays
            currentFrameIndex = 0
            imageView?.image = frames.first
        }

        func setPlaying(_ isPlaying: Bool) {
            if isPlaying {
                startPlayback()
            } else {
                stopPlayback()
            }
        }

        func startPlayback() {
            guard frames.count > 1, displayLink == nil else { return }

            lastFrameTime = 0
            accumulatedTime = 0
            let target = DisplayLinkTarget { [weak self] timestamp in
                self?.updateFrame(at: timestamp)
            }
            displayLink = CADisplayLink(
                target: target,
                selector: #selector(DisplayLinkTarget.handleDisplayLink(_:))
            )
            displayLink?.add(to: .main, forMode: .common)
        }

        func stopPlayback() {
            displayLink?.invalidate()
            displayLink = nil
            lastFrameTime = 0
            accumulatedTime = 0
        }

        private func updateFrame(at timestamp: CFTimeInterval) {
            guard frames.count > 1 else { return }

            if lastFrameTime == 0 {
                lastFrameTime = timestamp
                return
            }

            accumulatedTime += timestamp - lastFrameTime
            lastFrameTime = timestamp

            while accumulatedTime >= frameDuration(at: currentFrameIndex) {
                accumulatedTime -= frameDuration(at: currentFrameIndex)
                currentFrameIndex = (currentFrameIndex + 1) % frames.count
                imageView?.image = frames[currentFrameIndex]
            }
        }

        private func frameDuration(at index: Int) -> TimeInterval {
            guard delays.indices.contains(index), delays[index].isFinite else {
                return 1.0 / 60.0
            }
            return max(delays[index], 1.0 / 60.0)
        }
    }
}

private final class DisplayLinkTarget {
    private let callback: (CFTimeInterval) -> Void

    init(callback: @escaping (CFTimeInterval) -> Void) {
        self.callback = callback
    }

    @objc func handleDisplayLink(_ displayLink: CADisplayLink) {
        callback(displayLink.timestamp)
    }
}
#elseif os(macOS)
private struct UgoiraAppKitPlayer: NSViewRepresentable {
    let frames: [NSImage]
    let frameDelays: [TimeInterval]
    let isPlaying: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        context.coordinator.imageView = imageView
        context.coordinator.update(frames: frames, delays: frameDelays)
        context.coordinator.setPlaying(isPlaying)
        return imageView
    }

    func updateNSView(_ imageView: NSImageView, context: Context) {
        context.coordinator.imageView = imageView
        context.coordinator.update(frames: frames, delays: frameDelays)
        context.coordinator.setPlaying(isPlaying)
    }

    static func dismantleNSView(_ imageView: NSImageView, coordinator: Coordinator) {
        coordinator.stopPlayback()
        coordinator.imageView = nil
    }

    final class Coordinator {
        weak var imageView: NSImageView?
        private var frames: [NSImage] = []
        private var delays: [TimeInterval] = []
        private var currentFrameIndex = 0
        private var playbackTask: Task<Void, Never>?

        func update(frames: [NSImage], delays: [TimeInterval]) {
            guard self.frames.count != frames.count || self.frames.first !== frames.first else {
                return
            }

            stopPlayback()
            self.frames = frames
            self.delays = delays
            currentFrameIndex = 0
            imageView?.image = frames.first
        }

        func setPlaying(_ isPlaying: Bool) {
            if isPlaying {
                startPlayback()
            } else {
                stopPlayback()
            }
        }

        func startPlayback() {
            guard frames.count > 1, playbackTask == nil else { return }

            playbackTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    guard let self, self.frames.indices.contains(self.currentFrameIndex) else { break }
                    let delay = self.frameDuration(at: self.currentFrameIndex)

                    do {
                        try await Task.sleep(for: .seconds(delay))
                    } catch {
                        break
                    }

                    guard !Task.isCancelled else { break }
                    self.currentFrameIndex = (self.currentFrameIndex + 1) % self.frames.count
                    self.imageView?.image = self.frames[self.currentFrameIndex]
                }
            }
        }

        func stopPlayback() {
            playbackTask?.cancel()
            playbackTask = nil
        }

        private func frameDuration(at index: Int) -> TimeInterval {
            guard delays.indices.contains(index), delays[index].isFinite else {
                return 1.0 / 60.0
            }
            return max(delays[index], 1.0 / 60.0)
        }
    }
}
#endif

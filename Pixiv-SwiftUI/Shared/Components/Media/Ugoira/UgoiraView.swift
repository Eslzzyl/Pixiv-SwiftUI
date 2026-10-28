import SwiftUI
import Kingfisher

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct UgoiraView: View {
    let frameURLs: [URL]
    let frameDelays: [TimeInterval]
    let aspectRatio: CGFloat
    let expiration: CacheExpiration
    let shouldAutoPlay: Bool
    @Binding var isPlaying: Bool

    @Environment(\.displayScale) private var displayScale
    @State private var preparedFrames: [KFCrossPlatformImage] = []

    init(
        frameURLs: [URL],
        frameDelays: [TimeInterval],
        aspectRatio: CGFloat,
        expiration: CacheExpiration = .hours(1),
        shouldAutoPlay: Bool = true,
        isPlaying: Binding<Bool> = .constant(false)
    ) {
        self.frameURLs = frameURLs
        self.frameDelays = frameDelays
        self.aspectRatio = aspectRatio
        self.expiration = expiration
        self.shouldAutoPlay = shouldAutoPlay
        self._isPlaying = isPlaying
    }

    var body: some View {
        GeometryReader { geometry in
            let targetSize = geometry.size
            ZStack {
                if preparedFrames.count == frameURLs.count, !preparedFrames.isEmpty {
                    UgoiraPlatformPlayer(
                        frames: preparedFrames,
                        frameDelays: frameDelays,
                        isPlaying: isPlaying
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    ProgressView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .task(
                id: FramePreparationKey(
                    frameURLs: frameURLs,
                    targetSize: targetSize,
                    displayScale: displayScale
                )
            ) {
                preparedFrames = await UgoiraFrameCache.load(
                    frameURLs: frameURLs,
                    targetSize: targetSize,
                    displayScale: displayScale,
                    expiration: expiration
                ) ?? []
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .onAppear {
            if shouldAutoPlay {
                isPlaying = true
            }
        }
        .onDisappear {
            preparedFrames.removeAll(keepingCapacity: false)
        }
    }
}

private struct FramePreparationKey: Equatable {
    let frameURLs: [URL]
    let targetSize: CGSize
    let displayScale: CGFloat
}

#Preview {
    UgoiraView(
        frameURLs: [],
        frameDelays: [0.1, 0.1, 0.1],
        aspectRatio: 1.5
    )
    .frame(width: 300, height: 200)
}

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
    let thumbnailURL: String?
    @Binding var isPlaying: Bool

    @Environment(\.displayScale) private var displayScale
    @State private var preparedFrames: [KFCrossPlatformImage] = []

    init(
        frameURLs: [URL],
        frameDelays: [TimeInterval],
        aspectRatio: CGFloat,
        expiration: CacheExpiration = .hours(1),
        thumbnailURL: String? = nil,
        shouldAutoPlay: Bool = true,
        isPlaying: Binding<Bool> = .constant(true)
    ) {
        self.frameURLs = frameURLs
        self.frameDelays = frameDelays
        self.aspectRatio = aspectRatio
        self.expiration = expiration
        self.thumbnailURL = thumbnailURL
        self._isPlaying = isPlaying
    }

    var body: some View {
        GeometryReader { geometry in
            let targetSize = geometry.size
            ZStack {
                if let thumbnailURL, preparedFrames.isEmpty {
                    CachedAsyncImage(
                        urlString: thumbnailURL,
                        aspectRatio: aspectRatio,
                        contentMode: .fit
                    )
                }

                if !preparedFrames.isEmpty {
                    UgoiraPlatformPlayer(
                        frames: preparedFrames,
                        frameDelays: frameDelays,
                        isPlaying: isPlaying
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
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
                guard targetSize.width > 0, targetSize.height > 0 else { return }
                if let frames = await UgoiraFrameCache.shared.load(
                    frameURLs: frameURLs,
                    targetSize: targetSize,
                    displayScale: displayScale,
                    expiration: expiration
                ), !frames.isEmpty {
                    preparedFrames = frames
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
}

private struct FramePreparationKey: Equatable {
    let frameURLs: [URL]
    let pixelBucket: Int
    let displayScale: CGFloat

    init(frameURLs: [URL], targetSize: CGSize, displayScale: CGFloat) {
        self.frameURLs = frameURLs
        self.displayScale = displayScale
        let maxDim = max(targetSize.width, targetSize.height) * max(displayScale, 1)
        self.pixelBucket = max(0, Int((maxDim / 32.0).rounded(.up)) * 32)
    }
}

#Preview {
    UgoiraView(
        frameURLs: [],
        frameDelays: [0.1, 0.1, 0.1],
        aspectRatio: 1.5
    )
    .frame(width: 300, height: 200)
}

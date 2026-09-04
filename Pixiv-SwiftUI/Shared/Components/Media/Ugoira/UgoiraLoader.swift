import SwiftUI
import Kingfisher

struct UgoiraLoader: View {
    let illust: Illusts
    let store: UgoiraStore
    let expiration: CacheExpiration
    @Binding var isFullscreen: Bool

    @Environment(UserSettingStore.self) private var userSettingStore
    @State private var showPlayer = false
    @State private var isInlinePlaying = false
    @State private var shouldAutoStartInlinePlayback = false

    init(illust: Illusts, store: UgoiraStore, isFullscreen: Binding<Bool>, expiration: CacheExpiration = .hours(1)) {
        self.illust = illust
        self.store = store
        self.expiration = expiration
        self._isFullscreen = isFullscreen
    }

    private var aspectRatio: CGFloat {
        illust.safeAspectRatio
    }

    var body: some View {
        ZStack {
            Button(action: {
                if store.isReady {
                    #if os(macOS)
                    ImageViewerWindowManager.shared.showUgoira(illust: illust, store: store)
                    #else
                    isFullscreen = true
                    #endif
                }
            }) {
                content
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            statusOverlay
        }
        .task {
            await store.loadIfNeeded()
        }
        .onDisappear {
            store.cancelDownload()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.status {
        case .idle, .downloading, .unzipping:
            thumbnailView

        case .ready, .playing:
            if store.isReady, !store.frameURLs.isEmpty {
                if userSettingStore.userSetting.autoPlayUgoira || showPlayer {
                    UgoiraView(
                        frameURLs: store.frameURLs,
                        frameDelays: store.frameDelays,
                        aspectRatio: aspectRatio,
                        expiration: expiration,
                        shouldAutoPlay: userSettingStore.userSetting.autoPlayUgoira || shouldAutoStartInlinePlayback,
                        isPlaying: $isInlinePlaying
                    )
                } else {
                    thumbnailView
                }
            } else {
                thumbnailView
            }

        case .error:
            thumbnailView
                .overlay(alignment: .center) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                }
        }
    }

    private var thumbnailView: some View {
        CachedAsyncImage(
            urlString: ImageURLHelper.getImageURL(from: illust, quality: userSettingStore.userSetting.pictureQuality),
            aspectRatio: aspectRatio,
            contentMode: .fit
        )
        .clipped()
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch store.status {
        case .idle:
            playButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

        case .downloading(let receivedBytes, let totalBytes):
            UgoiraLoadingStatusCard(
                state: .downloading(receivedBytes: receivedBytes, totalBytes: totalBytes),
                onCancel: { store.cancelDownload() }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

        case .unzipping:
            UgoiraLoadingStatusCard(state: .unzipping)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

        case .ready, .playing:
            if !userSettingStore.userSetting.autoPlayUgoira {
                playButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            } else {
                EmptyView()
            }

        case .error:
            Button(action: { store.startDownload() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.orange.opacity(0.8))
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private var playButton: some View {
        Button(action: { handlePlayAction() }) {
            Image(systemName: isInlinePlaying ? "pause.fill" : "play.fill")
                .font(.title2)
                .foregroundColor(.black)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .adaptiveCircularGlassButtonStyle()
        .accessibilityLabel(isInlinePlaying ? String(localized: "暂停") : String(localized: "播放"))
        .padding(12)
    }

    private func handlePlayAction() {
        if !store.isReady {
            showPlayer = true
            shouldAutoStartInlinePlayback = true
            isInlinePlaying = true
            store.startDownload()
            return
        }

        if !showPlayer {
            showPlayer = true
            shouldAutoStartInlinePlayback = true
            isInlinePlaying = true
            return
        }

        isInlinePlaying.toggle()
    }
}

enum UgoiraLoadingVisualState {
    case downloading(receivedBytes: Int64, totalBytes: Int64?)
    case unzipping
}

struct UgoiraLoadingStatusCard: View {
    let state: UgoiraLoadingVisualState
    var onCancel: (() -> Void)?
    @Environment(ThemeManager.self) var themeManager

    private var titleText: String {
        switch state {
        case .downloading:
            return "下载中"
        case .unzipping:
            return "解压中"
        }
    }

    private var detailText: String {
        switch state {
        case .downloading(let receivedBytes, let totalBytes):
            let receivedText = NumberFormatter.formatFileSize(receivedBytes)
            if let totalBytes, totalBytes > 0 {
                return "已下载 \(receivedText) / \(NumberFormatter.formatFileSize(totalBytes))"
            }
            return "已下载 \(receivedText)"
        case .unzipping:
            return "正在处理帧缓存"
        }
    }

    private var progress: Double? {
        switch state {
        case .downloading(let receivedBytes, let totalBytes):
            guard let totalBytes, totalBytes > 0 else { return nil }
            return min(max(Double(receivedBytes) / Double(totalBytes), 0), 1)
        case .unzipping:
            return nil
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            UgoiraProgressIndicator(progress: progress)

            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(detailText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let onCancel {
                Spacer(minLength: 8)
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("取消下载")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            if #available(iOS 26.0, macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
    }
}

struct UgoiraProgressIndicator: View {
    let progress: Double?
    @Environment(ThemeManager.self) var themeManager

    var body: some View {
        Group {
            if let progress {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.25), lineWidth: 3)

                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(themeManager.currentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .animation(.easeInOut(duration: 0.2), value: progress)
                .frame(width: 28, height: 28)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28, height: 28)
            }
        }
    }
}

#Preview {
    let store = UgoiraStore(illustId: 123)
    return UgoiraLoader(
        illust: Illusts(
            id: 123,
            title: "测试",
            type: "ugoira",
            imageUrls: ImageUrls(
                squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p0_square1200.jpg",
                medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
                large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
            ),
            caption: "",
            restrict: 0,
            user: User(
                profileImageUrls: ProfileImageUrls(px16x16: "", px50x50: "", px170x170: ""),
                id: .string("1"),
                name: "测试",
                account: "test"
            ),
            tags: [],
            tools: [],
            createDate: "2023-12-15T00:00:00+09:00",
            pageCount: 1,
            width: 1200,
            height: 1600,
            sanityLevel: 2,
            xRestrict: 0,
            metaSinglePage: nil,
            metaPages: [],
            totalView: 1000,
            totalBookmarks: 500,
            isBookmarked: false,
            bookmarkRestrict: nil,
            visible: true,
            isMuted: false,
            illustAIType: 0
        ),
        store: store,
        isFullscreen: .constant(false)
    )
    .frame(width: 390, height: 520)
}

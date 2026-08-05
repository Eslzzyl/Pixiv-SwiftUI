#if os(iOS)
import SwiftUI
import UIKit

struct FullscreenImageView: View {
    let imageURLs: [String]
    let fallbackImageURLs: [String]
    let aspectRatios: [CGFloat]
    @Binding var initialPage: Int
    @Binding var isPresented: Bool
    @Binding var exitDragProgress: CGFloat
    var ugoiraStore: UgoiraStore?

    @State private var backgroundOpacity: CGFloat = 1
    @State private var dismissProgress: CGFloat = 0
    @State private var showTranslation = false
    @State private var translationStore = ImageTranslationStore()
    private let pages: [FullscreenImagePage]
    private let pagesReloadID: AnyHashable

    init(
        imageURLs: [String],
        fallbackImageURLs: [String],
        aspectRatios: [CGFloat],
        initialPage: Binding<Int>,
        isPresented: Binding<Bool>,
        exitDragProgress: Binding<CGFloat>,
        ugoiraStore: UgoiraStore? = nil
    ) {
        self.imageURLs = imageURLs
        self.fallbackImageURLs = fallbackImageURLs
        self.aspectRatios = aspectRatios
        self._initialPage = initialPage
        self._isPresented = isPresented
        self._exitDragProgress = exitDragProgress
        self.ugoiraStore = ugoiraStore

        let pages = imageURLs.enumerated().map { index, imageURL in
            FullscreenImagePage(
                index: index,
                imageURL: imageURL,
                fallbackImageURL: fallbackImageURLs.indices.contains(index) ? fallbackImageURLs[index] : nil,
                aspectRatio: aspectRatios.indices.contains(index) ? aspectRatios[index] : 1
            )
        }
        self.pages = pages
        self.pagesReloadID = AnyHashable(pages)
    }

    private var dismissScale: CGFloat {
        1 - min(1, max(0, dismissProgress)) * 0.3
    }

    var body: some View {
        ZStack {
            if pages.isEmpty {
                Color.black
                    .ignoresSafeArea()
            } else {
                Color.black
                    .opacity(Double(backgroundOpacity))
                    .ignoresSafeArea()

                LazyPager(data: pages, page: $initialPage) { page in
                    pageContent(page)
                }
                .zoomable(min: 1, max: 5)
                .reloadID(pagesReloadID)
                .onDismiss(
                    backgroundOpacity: $backgroundOpacity,
                    dismissProgress: $dismissProgress
                ) {
                    exitDragProgress = dismissProgress
                    isPresented = false
                }
                .onTap {
                    isPresented = false
                }
                .settings {
                    $0.dismissTriggerOffset = 0.06
                    $0.dismissVelocity = 0.8
                    $0.preloadAmount = 1
                }
                .background(ClearFullScreenBackground())
                .ignoresSafeArea()
                .scaleEffect(dismissScale)
                .contextMenu {
                    Button(action: translateCurrentImage) {
                        Label("翻译图片", systemImage: "text.bubble")
                    }
                    if UserSettingStore.shared.userSetting.vlmEnabled {
                        Button(action: explainCurrentImage) {
                            Label("解释图片", systemImage: "wand.and.stars")
                        }
                    }
                }
            }

            fullscreenOverlay
                .opacity(Double(max(0, min(1, backgroundOpacity * 2))))
        }
        .onAppear {
            backgroundOpacity = 1
            dismissProgress = 0
            if !pages.indices.contains(initialPage) {
                initialPage = 0
            }
        }
        .sheet(isPresented: $showTranslation) {
            ImageTranslationPanelView(store: translationStore) {
                showTranslation = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func pageContent(_ page: FullscreenImagePage) -> some View {
        pageView(page)
    }

    @ViewBuilder
    private func pageView(_ page: FullscreenImagePage) -> some View {
        if page.index == 0, let store = ugoiraStore, store.isReady {
            UgoiraView(
                frameURLs: store.frameURLs,
                frameDelays: store.frameDelays,
                aspectRatio: page.aspectRatio,
                expiration: store.expiration,
                shouldAutoPlay: true,
                isPlaying: .constant(true)
            )
        } else {
            ProgressiveCachedAsyncImage(
                targetURL: page.imageURL,
                fallbackURLs: page.fallbackImageURL.map { [$0] } ?? [],
                aspectRatio: page.aspectRatio,
                contentMode: .fit,
                idealWidth: UIScreen.main.bounds.width,
                expiration: DefaultCacheExpiration.illustDetail
            )
        }
    }

    private var fullscreenOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background {
                            if #available(iOS 26.0, *) {
                                Color.clear
                                    .glassEffect(.regular, in: Circle())
                            } else {
                                Circle()
                                    .fill(.ultraThinMaterial)
                            }
                        }
                }
                .accessibilityLabel(String(localized: "关闭"))
                .padding()
            }

            Spacer()

            if pages.count > 1 {
                Text("\(initialPage + 1) / \(pages.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        if #available(iOS 26.0, *) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.clear)
                                .glassEffect(.regular, in: .rect(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .padding(.bottom, 20)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func translateCurrentImage() {
        guard let page = pages[safe: initialPage] else { return }
        showTranslation = true
        Task {
            await translationStore.translateImage(urlString: page.imageURL)
        }
    }

    private func explainCurrentImage() {
        guard let page = pages[safe: initialPage] else { return }
        showTranslation = true
        Task {
            await translationStore.explainImage(urlString: page.imageURL)
        }
    }
}

private struct FullscreenImagePage: Hashable {
    let index: Int
    let imageURL: String
    let fallbackImageURL: String?
    let aspectRatio: CGFloat
}

#Preview("Fullscreen Pager") {
    FullscreenImageView(
        imageURLs: [
            "preview-image-0",
            "preview-image-1"
        ],
        fallbackImageURLs: [],
        aspectRatios: [0.75, 0.75],
        initialPage: .constant(0),
        isPresented: .constant(true),
        exitDragProgress: .constant(0)
    )
    .frame(width: 390, height: 844)
}
#endif

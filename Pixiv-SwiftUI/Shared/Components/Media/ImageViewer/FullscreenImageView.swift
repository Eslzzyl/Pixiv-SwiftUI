import SwiftUI

struct FullscreenImageView: View {
    let imageURLs: [String]
    let fallbackImageURLs: [String]
    let aspectRatios: [CGFloat]
    @Binding var initialPage: Int
    @Binding var isPresented: Bool
    @Binding var exitDragProgress: CGFloat
    var animation: Namespace.ID
    var ugoiraStore: UgoiraStore?       // When set, page 0 shows animated ugoira instead of static image
    @State private var currentPage: Int = 0
    @State private var dismissProgress: CGFloat = 0
    @State private var isZoomed: Bool = false
    @State private var showTranslation = false
    @State private var translationStore = ImageTranslationStore()

    private var scale: CGFloat {
        1.0 - dismissProgress * 0.3
    }

    private var backgroundOpacity: Double {
        1.0 - Double(dismissProgress)
    }

    private var isUgoiraPage: Bool {
        ugoiraStore?.isReady == true
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(0..<imageURLs.count, id: \.self) { (index: Int) in
                            if index == 0, isUgoiraPage, let store = ugoiraStore {
                                // Ugoira page — zoomable animated content
                                ZoomableUgoiraContent(
                                    frameURLs: store.frameURLs,
                                    frameDelays: store.frameDelays,
                                    aspectRatio: index < aspectRatios.count ? aspectRatios[index] : 1,
                                    expiration: store.expiration,
                                    onDismiss: {
                                        isPresented = false
                                    },
                                    isZoomed: $isZoomed,
                                    onDragProgress: { progress in
                                        dismissProgress = progress
                                    },
                                    onDragEnded: { shouldDismiss in
                                        if shouldDismiss {
                                            exitDragProgress = dismissProgress
                                            isPresented = false
                                        } else {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                dismissProgress = 0
                                            }
                                        }
                                    }
                                )
                                .containerRelativeFrame(.horizontal)
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
                            } else {
                                // Static image page
                                ZoomableAsyncImage(
                                    urlString: imageURLs[index],
                                    fallbackURL: index < fallbackImageURLs.count ? fallbackImageURLs[index] : nil,
                                    aspectRatio: index < aspectRatios.count ? aspectRatios[index] : nil,
                                    onDismiss: {
                                        isPresented = false
                                    },
                                    isZoomed: $isZoomed,
                                    onDragProgress: { progress in
                                        dismissProgress = progress
                                    },
                                    onDragEnded: { shouldDismiss in
                                        if shouldDismiss {
                                            exitDragProgress = dismissProgress
                                            isPresented = false
                                        } else {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                dismissProgress = 0
                                            }
                                        }
                                    }
                                )
                                .containerRelativeFrame(.horizontal)
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
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .ignoresSafeArea()
                .scaleEffect(scale)
                .offset(y: dismissProgress * geometry.size.height)

                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background {
                                    if #available(iOS 26.0, macOS 26.0, *) {
                                        Color.clear
                                            .glassEffect(.regular.interactive(), in: Circle())
                                    } else {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    }
                                }
                        }
                        .padding()
                    }
                    Spacer()

                    if imageURLs.count > 1 {
                        Text("\(currentPage + 1) / \(imageURLs.count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background {
                                if #available(iOS 26.0, macOS 26.0, *) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.clear)
                                        .glassEffect(.regular, in: .rect(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                }
                            }
                            .padding(.bottom, 20)
                    }
                }
                .opacity(Double(1 - dismissProgress * 2))
            }
            .onAppear {
                currentPage = initialPage
            }
            .sheet(isPresented: $showTranslation) {
                ImageTranslationPanelView(store: translationStore) {
                    showTranslation = false
                }
                #if os(iOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                #endif
            }
        }
    }

    private func translateCurrentImage() {
        let url: String
        if imageURLs.indices.contains(currentPage) {
            url = imageURLs[currentPage]
        } else if let first = imageURLs.first {
            url = first
        } else {
            return
        }
        showTranslation = true
        Task {
            await translationStore.translateImage(urlString: url)
        }
    }

    private func explainCurrentImage() {
        let url: String
        if imageURLs.indices.contains(currentPage) {
            url = imageURLs[currentPage]
        } else if let first = imageURLs.first {
            url = first
        } else {
            return
        }
        showTranslation = true
        Task {
            await translationStore.explainImage(urlString: url)
        }
    }
}

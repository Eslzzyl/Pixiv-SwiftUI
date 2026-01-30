import SwiftUI
import Kingfisher
import UniformTypeIdentifiers
#if os(macOS)
import AppKit

struct ImageViewerWindowContent: View {
    let illust: Illusts?
    let imageURLs: [String]
    let aspectRatios: [CGFloat]
    let initialPage: Int
    let title: String
    let onClose: () -> Void

    @State private var currentPage: Int
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isHoveringTop = false

    init(illust: Illusts? = nil, imageURLs: [String], aspectRatios: [CGFloat], initialPage: Int, title: String, onClose: @escaping () -> Void) {
        self.illust = illust
        self.imageURLs = imageURLs
        self.aspectRatios = aspectRatios
        self.initialPage = initialPage
        self.title = title
        self.onClose = onClose
        _currentPage = State(initialValue: initialPage)
    }

    private var isMultiPage: Bool {
        imageURLs.count > 1
    }

    private var currentAspectRatio: CGFloat {
        currentPage < aspectRatios.count ? aspectRatios[currentPage] : 1.0
    }

    var body: some View {
        ZStack {
            ImageContent(
                imageURLs: imageURLs,
                currentPage: $currentPage,
                scale: $scale,
                lastScale: $lastScale,
                offset: $offset,
                lastOffset: $lastOffset
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isMultiPage {
                PageNavigationOverlay(
                    currentPage: $currentPage,
                    totalPages: imageURLs.count
                )
            }

            BottomStatusBar(
                illust: illust,
                imageURLs: imageURLs,
                currentPage: currentPage,
                totalPages: imageURLs.count,
                scale: scale
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button(action: saveCurrentImage) {
                        Label("保存…", systemImage: "square.and.arrow.up")
                    }

                    Button(action: copyCurrentImage) {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                        )
                }
                .menuStyle(.borderlessButton)
            }
        }
        .onHover { hovering in
            isHoveringTop = hovering
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let delta = value / lastScale
                    lastScale = value
                    scale = min(max(scale * delta, 1.0), 5.0)
                }
                .onEnded { _ in
                    lastScale = 1.0
                }
        )
        .onTapGesture(count: 2) {
            withAnimation(.easeOut(duration: 0.2)) {
                if scale != 1.0 {
                    scale = 1.0
                } else {
                    scale = 2.0
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 123: // Left arrow
                if isMultiPage && currentPage > 0 {
                    withAnimation {
                        currentPage -= 1
                    }
                    resetZoom()
                }
                return nil
            case 124: // Right arrow
                if isMultiPage && currentPage < imageURLs.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                    resetZoom()
                }
                return nil
            case 53: // Escape
                onClose()
                return nil
            case 13: // W (Command+W handled by system)
                if event.modifierFlags.contains(.command) {
                    onClose()
                    return nil
                }
                return event
            case 1: // S
                if event.modifierFlags.contains(.command) {
                    saveCurrentImage()
                    return nil
                }
                return event
            case 8: // C
                if event.modifierFlags.contains(.command) {
                    copyCurrentImage()
                    return nil
                }
                return event
            case 29: // 0
                if event.modifierFlags.contains(.command) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        scale = 1.0
                    }
                    return nil
                }
                return event
            default:
                return event
            }
        }
    }

    private func resetZoom() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 1.0
        }
    }

    private func saveCurrentImage() {
        guard currentPage < imageURLs.count else { return }
        let urlString = imageURLs[currentPage]
        Task {
            await downloadAndSave(urlString: urlString)
        }
    }

    private func copyCurrentImage() {
        guard currentPage < imageURLs.count else { return }
        let urlString = imageURLs[currentPage]
        Task {
            await downloadAndCopy(urlString: urlString)
        }
    }

    @MainActor
    private func downloadAndSave(urlString: String) async {
        guard let url = URL(string: urlString) else { return }

        let source: Source = shouldUseDirectConnection(url: url)
            ? .directNetwork(url)
            : .network(Kingfisher.KF.ImageResource(downloadURL: url))

        do {
            let result = try await KingfisherManager.shared.retrieveImage(with: source)
            if let data = result.image.kf.pngRepresentation() {
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [UTType.png]
                savePanel.nameFieldStringValue = "image.png"

                let response = await withCheckedContinuation { continuation in
                    savePanel.begin { result in
                        continuation.resume(returning: result)
                    }
                }

                if response == .OK, let saveURL = savePanel.url {
                    try data.write(to: saveURL)
                }
            }
        } catch {
            print("[ImageViewer] Failed to save image: \(error)")
        }
    }

    @MainActor
    private func downloadAndCopy(urlString: String) async {
        guard let url = URL(string: urlString) else { return }

        let source: Source = shouldUseDirectConnection(url: url)
            ? .directNetwork(url)
            : .network(Kingfisher.KF.ImageResource(downloadURL: url))

        do {
            let result = try await KingfisherManager.shared.retrieveImage(with: source)
            let nsImage = result.image
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([nsImage])
        } catch {
            print("[ImageViewer] Failed to copy image: \(error)")
        }
    }

    private func shouldUseDirectConnection(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return NetworkModeStore.shared.useDirectConnection &&
               (host.contains("i.pximg.net") || host.contains("img-master.pixiv.net"))
    }
}

struct ImageContent: View {
    let imageURLs: [String]
    @Binding var currentPage: Int
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize

    var body: some View {
        ZStack {
            if currentPage < imageURLs.count {
                ZoomableImage(
                    urlString: imageURLs[currentPage],
                    scale: $scale,
                    lastScale: $lastScale,
                    offset: $offset,
                    lastOffset: $lastOffset
                )
                .id(currentPage)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentPage)
        .ignoresSafeArea()
        .allowsHitTesting(scale <= 1.0)
    }
}

struct ZoomableImage: View {
    let urlString: String
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                CachedAsyncImage(
                    urlString: urlString,
                    aspectRatio: nil,
                    contentMode: .fill
                )
                .scaleEffect(scale)
                .frame(
                    width: geometry.size.width * max(scale, 1.0),
                    height: geometry.size.height * max(scale, 1.0)
                )
            }
            .background(Color.black.opacity(0.001)) // Make sure background is interactive
        }
    }
}

struct PageNavigationOverlay: View {
    @Binding var currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack {
            Button(action: {
                if currentPage > 0 {
                    withAnimation {
                        currentPage -= 1
                    }
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(currentPage == 0)

            Spacer()

            Button(action: {
                if currentPage < totalPages - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(currentPage == totalPages - 1)
        }
        .padding(.horizontal, 20)
    }
}

struct TopToolbar: View {
    let onSave: () -> Void
    let onCopy: () -> Void
    let isHovering: Bool

    var body: some View {
        VStack {
            HStack {
                Spacer()

                Menu {
                    Button(action: onSave) {
                        Label("保存…", systemImage: "square.and.arrow.down")
                    }

                    Button(action: onCopy) {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                }
                .menuStyle(.borderlessButton)
            }
            .padding()

            Spacer()
        }
        .opacity(isHovering ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
    }
}

struct MetadataTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
    }
}

struct BottomStatusBar: View {
    let illust: Illusts?
    let imageURLs: [String]
    let currentPage: Int
    let totalPages: Int
    let scale: CGFloat

    private var format: String {
        guard currentPage < imageURLs.count else { return "" }
        let url = imageURLs[currentPage].lowercased()
        if url.contains(".png") { return "PNG" }
        if url.contains(".gif") { return "GIF" }
        return "JPG"
    }

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 8) {
                if let illust = illust {
                    MetadataTag(text: "PID \(illust.id)")
                    MetadataTag(text: "\(illust.width)x\(illust.height)")
                }

                MetadataTag(text: format)

                if totalPages > 1 {
                    MetadataTag(text: "\(currentPage + 1) / \(totalPages)")
                }

                if scale != 1.0 {
                    MetadataTag(text: "\(Int(scale * 100))%")
                }

                Spacer()
            }
            .padding(16)
        }
    }
}

#Preview("Image Viewer") {
    ImageViewerWindowContent(
        illust: nil,
        imageURLs: [
            "https://i.pximg.net/img-master/img/2024/01/01/00/00/00/12345678_p0_master1200.jpg"
        ],
        aspectRatios: [0.75],
        initialPage: 0,
        title: "测试图片",
        onClose: {}
    )
    .frame(width: 800, height: 600)
}

#endif

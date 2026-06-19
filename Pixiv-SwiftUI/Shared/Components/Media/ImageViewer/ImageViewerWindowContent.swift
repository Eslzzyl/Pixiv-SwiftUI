import SwiftUI
import Kingfisher
import os.log
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
    @State private var eventMonitor: Any?
    @State private var viewWindow: NSWindow?
    @State private var showTranslation = false
    @State private var translationStore = ImageTranslationStore()

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
                Spacer()
                Menu {
                    Button(action: saveCurrentImage) {
                        Label("保存…", systemImage: "square.and.arrow.down")
                    }

                    Button(action: copyCurrentImage) {
                        Label("复制", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button(action: translateCurrentImage) {
                        Label("翻译图片", systemImage: "text.bubble")
                    }

                    if UserSettingStore.shared.userSetting.vlmEnabled {
                        Button(action: explainCurrentImage) {
                            Label("解释图片", systemImage: "wand.and.stars")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
            }
        }
        .onHover { hovering in
            isHoveringTop = hovering
        }
        .background(
            HostingWindowFinder { window in
                self.viewWindow = window
            }
        )
        .onAppear {
            setupEvents()
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
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
                    resetZoom()
                } else {
                    scale = 2.0
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .sheet(isPresented: $showTranslation) {
            ImageTranslationPanelView(store: translationStore) {
                showTranslation = false
            }
            .frame(width: 400, height: 500)
        }
    }

    private func setupEvents() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) { [weak NSApp] event in
            // IMPORTANT: Only handle events for the window containing this view.
            // We use the stored viewWindow instead of keyWindow to prevent blocking other windows.
            guard let eventWindow = event.window,
                  let viewWindow = self.viewWindow,
                  eventWindow == viewWindow else { return event }

            // Ensure this monitor doesn't catch events after it should have been removed
            // but just in case of race conditions or delay in NSHostingController disposal.
            if eventMonitor == nil { return event }

            if event.type == .scrollWheel {
                return handleScrollWheel(event)
            }
            return handleKeyEvent(event)
        }
    }

    private func handleScrollWheel(_ event: NSEvent) -> NSEvent? {
        let hasModifier = event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option)

        // Only zoom if modifier is held.
        // This avoids conflict with ScrollView panning and prevents accidental zoom leaks.
        if hasModifier {
            let delta = event.scrollingDeltaY
            if abs(delta) > 0 {
                let isTrackpad = event.hasPreciseScrollingDeltas
                let multiplier: CGFloat = isTrackpad ? 0.02 : 0.05
                let zoomFactor = 1.0 + (delta * multiplier)
                let newScale = min(max(scale * zoomFactor, 1.0), 5.0)

                if newScale == 1.0 {
                    resetZoom()
                } else {
                    scale = newScale
                }
                return nil
            }
        } else if scale > 1.0 {
            // Panning logic for trackpad/mouse wheel without modifier
            let deltaX = event.scrollingDeltaX
            let deltaY = event.scrollingDeltaY

            if abs(deltaX) > 0 || abs(deltaY) > 0 {
                // Use the same constraint logic as DragGesture
                // We need the geometry size, but since this is a global monitor, 
                // we'll approximate or use a simplified constraint if geometry.size is unavailable here.
                // Actually, to be accurate, we should move the offset calculation 
                // to somewhere that knows the view size.
                // For now, let's update simple offset and let the UI constrain it if possible,
                // but here we deal with the State directly.

                let currentWindow = event.window
                let windowSize = currentWindow?.contentView?.frame.size ?? .zero

                let newOffset = CGSize(
                    width: offset.width + deltaX,
                    height: offset.height + deltaY
                )

                // We use the window size as a proxy for the ImageContent size
                let zoomedWidth = windowSize.width * scale
                let zoomedHeight = windowSize.height * scale
                let maxW = max(0, (zoomedWidth - windowSize.width) / 2)
                let maxH = max(0, (zoomedHeight - windowSize.height) / 2)

                offset = CGSize(
                    width: min(max(newOffset.width, -maxW), maxW),
                    height: min(max(newOffset.height, -maxH), maxH)
                )
                lastOffset = offset
                return nil
            }
        }
        return event
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
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

    private func resetZoom() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 1.0
            offset = .zero
            lastOffset = .zero
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

    private func translateCurrentImage() {
        guard currentPage < imageURLs.count else { return }
        let urlString = imageURLs[currentPage]
        showTranslation = true
        Task {
            await translationStore.translateImage(urlString: urlString)
        }
    }

    private func explainCurrentImage() {
        guard currentPage < imageURLs.count else { return }
        let urlString = imageURLs[currentPage]
        showTranslation = true
        Task {
            await translationStore.explainImage(urlString: urlString)
        }
    }

    @MainActor
    private func downloadAndSave(urlString: String) async {
        guard let url = URL(string: urlString) else { return }

        // 构建文件名
        let safeTitle: String
        let safeAuthor: String

        if let illust = illust {
            safeTitle = ImageSaver.sanitizeFilename(illust.title)
            safeAuthor = ImageSaver.sanitizeFilename(illust.user.name)
        } else {
            // 如果没有 illust 信息，使用 title 参数
            safeTitle = ImageSaver.sanitizeFilename(title)
            safeAuthor = ""
        }

        var filename = safeAuthor.isEmpty ? safeTitle : "\(safeAuthor)_\(safeTitle)"
        if isMultiPage {
            filename += "_p\(currentPage)"
        }
        filename += ".png"

        let source: Source = shouldUseDirectConnection(url: url)
            ? .directNetwork(url)
            : .network(Kingfisher.KF.ImageResource(downloadURL: url))

        do {
            let result = try await KingfisherManager.shared.retrieveImage(with: source)
            if let data = result.image.kf.pngRepresentation() {
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [UTType.png]
                savePanel.nameFieldStringValue = filename

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
            Logger.general.error("Failed to save image: \(error)")
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
            Logger.general.error("Failed to copy image: \(error)")
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
            CachedAsyncImage(
                urlString: urlString,
                aspectRatio: nil,
                contentMode: .fit
            )
            .scaleEffect(scale)
            .offset(offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if scale > 1.0 {
                            let newOffset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                            offset = constrainOffset(newOffset, in: geometry.size)
                        }
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
        }
    }

    private func constrainOffset(_ newOffset: CGSize, in size: CGSize) -> CGSize {
        guard scale > 1.0 else { return .zero }

        let zoomedWidth = size.width * scale
        let zoomedHeight = size.height * scale

        // The maximum distance the image can move from the center
        // (zoomedSize - viewportSize) / 2
        let maxW = max(0, (zoomedWidth - size.width) / 2)
        let maxH = max(0, (zoomedHeight - size.height) / 2)

        return CGSize(
            width: min(max(newOffset.width, -maxW), maxW),
            height: min(max(newOffset.height, -maxH), maxH)
        )
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
                    .background {
                        if #available(iOS 26.0, macOS 26.0, *) {
                            Circle()
                                .fill(.clear)
                                .glassEffect(.regular.interactive(), in: .circle)
                        } else {
                            Circle()
                                .fill(.ultraThinMaterial)
                        }
                    }
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
                    .background {
                        if #available(iOS 26.0, macOS 26.0, *) {
                            Circle()
                                .fill(.clear)
                                .glassEffect(.regular.interactive(), in: .circle)
                        } else {
                            Circle()
                                .fill(.ultraThinMaterial)
                        }
                    }
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

struct MetadataTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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

// Helper to find the NSWindow hosting a SwiftUI view
struct HostingWindowFinder: NSViewRepresentable {
    var callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            callback(window)
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

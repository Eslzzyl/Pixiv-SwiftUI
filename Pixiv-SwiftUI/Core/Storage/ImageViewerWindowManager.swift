import SwiftUI
import Kingfisher
#if os(macOS)
import AppKit

@MainActor
final class ImageViewerWindowManager {
    static let shared = ImageViewerWindowManager()

    private var window: NSWindow?
    private var currentTask: Task<Void, Never>?

    private init() {}

    func showSingleImage(illust: Illusts, url: String, title: String, aspectRatio: CGFloat) {
        showMultiImages(illust: illust, urls: [url], initialPage: 0, title: title, aspectRatios: [aspectRatio])
    }

    func showMultiImages(illust: Illusts? = nil, urls: [String], initialPage: Int, title: String, aspectRatios: [CGFloat]) {
        guard !urls.isEmpty else { return }

        currentTask?.cancel()

        if let existingWindow = window {
            updateWindowContent(
                window: existingWindow,
                illust: illust,
                urls: urls,
                initialPage: initialPage,
                title: title,
                aspectRatios: aspectRatios
            )
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = ImageViewerWindowContent(
            illust: illust,
            imageURLs: urls,
            aspectRatios: aspectRatios,
            initialPage: initialPage,
            title: title,
            onClose: { [weak self] in
                self?.close()
            }
        )
        .frame(minWidth: 400, minHeight: 300)

        let hostingController = NSHostingController(rootView: contentView)

        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
                              styleMask: styleMask,
                              backing: .buffered,
                              defer: false)

        window.contentViewController = hostingController
        window.title = title
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.backgroundColor = .windowBackgroundColor

        window.standardWindowButton(.documentIconButton)?.isHidden = true
        window.standardWindowButton(.documentVersionsButton)?.isHidden = true

        adjustWindowSize(window: window, aspectRatios: aspectRatios, initialPage: initialPage)

        DispatchQueue.main.async {
            window.center()
            window.makeKeyAndOrderFront(nil)
        }

        self.window = window
    }

    func showUgoira(illust: Illusts, store: UgoiraStore) {
        currentTask?.cancel()

        if let existingWindow = window {
            updateWindowForUgoira(window: existingWindow, illust: illust, store: store)
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = UgoiraWindowContent(
            illust: illust,
            store: store,
            onClose: { [weak self] in
                self?.close()
            }
        )
        .frame(minWidth: 400, minHeight: 300)

        let hostingController = NSHostingController(rootView: contentView)

        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
                              styleMask: styleMask,
                              backing: .buffered,
                              defer: false)

        window.contentViewController = hostingController
        window.title = illust.title
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.backgroundColor = .windowBackgroundColor

        window.standardWindowButton(.documentIconButton)?.isHidden = true
        window.standardWindowButton(.documentVersionsButton)?.isHidden = true

        let aspectRatio = illust.safeAspectRatio
        adjustWindowSize(window: window, aspectRatios: [aspectRatio], initialPage: 0)

        DispatchQueue.main.async {
            window.center()
            window.makeKeyAndOrderFront(nil)
        }

        self.window = window
    }

    func close() {
        window?.orderOut(nil)
        window = nil
        currentTask?.cancel()
        currentTask = nil
    }

    private func updateWindowContent(window: NSWindow, illust: Illusts?, urls: [String], initialPage: Int, title: String, aspectRatios: [CGFloat]) {
        let contentView = ImageViewerWindowContent(
            illust: illust,
            imageURLs: urls,
            aspectRatios: aspectRatios,
            initialPage: initialPage,
            title: title,
            onClose: { [weak self] in
                self?.close()
            }
        )
        .frame(minWidth: 400, minHeight: 300)

        window.contentViewController = NSHostingController(rootView: contentView)
        window.title = title

        adjustWindowSize(window: window, aspectRatios: aspectRatios, initialPage: initialPage)
    }

    private func updateWindowForUgoira(window: NSWindow, illust: Illusts, store: UgoiraStore) {
        let contentView = UgoiraWindowContent(
            illust: illust,
            store: store,
            onClose: { [weak self] in
                self?.close()
            }
        )
        .frame(minWidth: 400, minHeight: 300)

        window.contentViewController = NSHostingController(rootView: contentView)
        window.title = illust.title

        let aspectRatio = illust.safeAspectRatio
        adjustWindowSize(window: window, aspectRatios: [aspectRatio], initialPage: 0)
    }

    private func adjustWindowSize(window: NSWindow, aspectRatios: [CGFloat], initialPage: Int) {
        guard let screen = window.screen ?? NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let screenWidth = screenFrame.width
        let screenHeight = screenFrame.height

        let maxWindowWidth = screenWidth * 0.9
        let maxWindowHeight = screenHeight * 0.9

        let aspectRatio = initialPage < aspectRatios.count ? aspectRatios[initialPage] : 1.0

        var windowSize: NSSize

        let maxAspectRatio = maxWindowWidth / maxWindowHeight

        if aspectRatio >= maxAspectRatio {
            windowSize = NSSize(width: maxWindowWidth, height: maxWindowWidth / aspectRatio)
        } else {
            windowSize = NSSize(width: maxWindowHeight * aspectRatio, height: maxWindowHeight)
        }

        windowSize.width = max(windowSize.width, 400)
        windowSize.height = max(windowSize.height, 300)

        let newFrame = NSRect(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY - windowSize.height / 2,
            width: windowSize.width,
            height: windowSize.height
        )

        window.setFrame(newFrame, display: true, animate: false)
    }
}

#endif

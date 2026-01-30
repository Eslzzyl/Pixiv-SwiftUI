import SwiftUI
import Kingfisher
import UniformTypeIdentifiers

#if os(macOS)

struct UgoiraWindowContent: View {
    let illust: Illusts
    @ObservedObject var store: UgoiraStore
    let onClose: () -> Void

    @State private var isHovering = false
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var showExportPanel = false

    private var aspectRatio: CGFloat {
        illust.safeAspectRatio
    }

    var body: some View {
        ZStack {
            if store.isReady, !store.frameURLs.isEmpty {
                UgoiraView(
                    frameURLs: store.frameURLs,
                    frameDelays: store.frameDelays,
                    aspectRatio: aspectRatio,
                    expiration: store.expiration,
                    shouldAutoPlay: true,
                    isPlaying: $isPlaying
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    if case .downloading(let progress) = store.status {
                        CircularProgressView(progress: progress)
                            .padding()
                    } else if case .unzipping = store.status {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("解压中...")
                            .foregroundColor(.secondary)
                    } else if case .error(let message) = store.status {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(message)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            Task {
                                await store.startDownload()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                }
            }

            UgoiraBottomStatusBar(
                illust: illust,
                isPlaying: $isPlaying,
                isPaused: $isPaused,
                onTogglePlay: {
                    isPaused.toggle()
                    isPlaying = !isPaused
                }
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button(action: { showExportPanel = true }) {
                        Label("导出 GIF", systemImage: "square.and.arrow.up")
                    }

                    Button(action: {
                        isPaused.toggle()
                        isPlaying = !isPaused
                    }) {
                        Label(
                            isPaused ? "播放" : "暂停",
                            systemImage: isPaused ? "play.fill" : "pause.fill"
                        )
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
            isHovering = hovering
        }
        .ignoresSafeArea()
        .onAppear {
            setupKeyboardShortcuts()
            Task {
                if !store.isReady {
                    await store.startDownload()
                }
            }
        }
        .sheet(isPresented: $showExportPanel) {
            ExportPanel(store: store, isPresented: $showExportPanel)
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 49: // Space
                isPaused.toggle()
                isPlaying = !isPaused
                return nil
            case 53: // Escape
                onClose()
                return nil
            case 13: // W
                if event.modifierFlags.contains(.command) {
                    onClose()
                    return nil
                }
                return event
            default:
                return event
            }
        }
    }
}

struct UgoiraMetadataTag: View {
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

struct UgoiraBottomStatusBar: View {
    let illust: Illusts
    @Binding var isPlaying: Bool
    @Binding var isPaused: Bool
    let onTogglePlay: () -> Void

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 8) {
                Button(action: onTogglePlay) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                UgoiraMetadataTag(text: "PID \(illust.id)")
                UgoiraMetadataTag(text: "\(illust.width)x\(illust.height)")
                UgoiraMetadataTag(text: "GIF")

                if isPaused {
                    UgoiraMetadataTag(text: "已暂停")
                } else if isPlaying {
                    UgoiraMetadataTag(text: "正在播放")
                }

                Spacer()
            }
            .padding(16)
        }
    }
}

struct ExportPanel: View {
    @ObservedObject var store: UgoiraStore
    @Binding var isPresented: Bool

    @State private var isExporting = false

    var body: some View {
        VStack(spacing: 20) {
            Text("导出 GIF")
                .font(.title2)
                .fontWeight(.semibold)

            if isExporting {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(width: 200)

                    Text("正在导出...")
                        .foregroundColor(.secondary)
                }
            } else {
                Text("将动图导出为 GIF 格式")
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button("取消") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)

                    Button("导出") {
                        exportGIF()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(30)
        .frame(width: 300)
    }

    private func exportGIF() {
        guard store.isReady, !store.frameURLs.isEmpty else { return }

        isExporting = true

        Task {
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(store.illustId)_ugoira.gif")

            do {
                try await GIFExporter.export(
                    frameURLs: store.frameURLs,
                    delays: store.frameDelays,
                    outputURL: outputURL
                )

                await MainActor.run {
                    isExporting = false
                    isPresented = false
                    showSavePanel(url: outputURL)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    print("[UgoiraWindow] Export failed: \(error)")
                }
            }
        }
    }

    @MainActor
    private func showSavePanel(url: URL) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.gif]
        savePanel.nameFieldStringValue = "\(store.illustId).gif"

        savePanel.begin { response in
            if response == .OK, let saveURL = savePanel.url {
                do {
                    if FileManager.default.fileExists(atPath: saveURL.path) {
                        try FileManager.default.removeItem(at: saveURL)
                    }
                    try FileManager.default.moveItem(at: url, to: saveURL)
                } catch {
                    print("[UgoiraWindow] Failed to save GIF: \(error)")
                }
            }
            try? FileManager.default.removeItem(at: url)
        }
    }
}

#Preview("Ugoira Viewer") {
    UgoiraWindowContent(
        illust: Illusts(
            id: 123,
            title: "测试动图",
            type: "ugoira",
            imageUrls: ImageUrls(
                squareMedium: "",
                medium: "",
                large: ""
            ),
            caption: "",
            restrict: 0,
            user: User(
                profileImageUrls: ProfileImageUrls(px16x16: "", px50x50: "", px170x170: ""),
                id: .string("1"),
                name: "测试用户",
                account: "test"
            ),
            tags: [],
            tools: [],
            createDate: "2024-01-01",
            pageCount: 1,
            width: 800,
            height: 600,
            sanityLevel: 0,
            xRestrict: 0,
            metaSinglePage: nil,
            metaPages: [],
            totalView: 0,
            totalBookmarks: 0,
            isBookmarked: false,
            bookmarkRestrict: nil,
            visible: true,
            isMuted: false,
            illustAIType: 0
        ),
        store: UgoiraStore(illustId: 123),
        onClose: {}
    )
    .frame(width: 800, height: 600)
}

#endif

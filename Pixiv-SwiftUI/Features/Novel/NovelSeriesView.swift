import SwiftUI
import TranslationKit
import UniformTypeIdentifiers

struct NovelSeriesView: View {
    let seriesId: Int
    @State private var store: NovelSeriesStore
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var showExportToast = false
    @State private var showDocumentPicker = false
    @State private var exportTempURL: URL?
    @State private var exportFilename: String = ""
    @State private var currentExportFormat: NovelExportFormat = .txt

    init(seriesId: Int) {
        self.seriesId = seriesId
        self._store = State(initialValue: NovelSeriesStore(seriesId: seriesId))
    }

    var body: some View {
        ScrollView {
            Group {
                if store.isLoading && store.seriesDetail == nil {
                    loadingView
                } else if let error = store.errorMessage {
                    errorView(error)
                } else if let detail = store.seriesDetail {
                    content(detail)
                }
            }
        }
        .id("SeriesScrollView-\(seriesId)")  // 添加稳定的 ID
        .navigationDestination(for: Novel.self) { novel in
            NovelDetailView(novel: novel)
        }
        .onAppear {
            print("[NovelSeriesView] onAppear - seriesId: \(seriesId)")
        }
        .refreshable {
            await store.fetch()
        }
        .keyboardShortcut("r", modifiers: .command)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toast(isPresented: $showExportToast, message: String(localized: "已添加到下载队列"))
        #if os(iOS)
        .sheet(isPresented: $showDocumentPicker) {
            if let tempURL = exportTempURL {
                DocumentPickerView(tempURL: tempURL, filename: exportFilename)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .novelExportDidComplete)) { notification in
            guard let userInfo = notification.userInfo,
                  let tempURL = userInfo["tempURL"] as? URL,
                  let filename = userInfo["filename"] as? String else { return }
            self.exportTempURL = tempURL
            self.exportFilename = filename
            self.showDocumentPicker = true
        }
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let detail = store.seriesDetail {
                    HStack(spacing: 8) {
                        CachedAsyncImage(
                            urlString: detail.user.profileImageUrls.medium,
                            expiration: DefaultCacheExpiration.userAvatar
                        )
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())

                        Text(detail.user.name)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: shareSeries) {
                        Label(String(localized: "分享系列链接"), systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Menu {
                        Button(action: { exportSeries(format: .txt) }) {
                            Label(String(localized: "导出为 TXT"), systemImage: "doc.text.fill")
                        }
                        Button(action: { exportSeries(format: .epub) }) {
                            Label(String(localized: "导出为 EPUB"), systemImage: "book.closed")
                        }
                    } label: {
                        Label(String(localized: "导出"), systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            #if os(macOS)
            ToolbarItem {
                RefreshButton(refreshAction: { await store.fetch() })
            }
            #endif
        }
        .task {
            if store.seriesDetail == nil {
                await store.fetch()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                #if os(macOS)
                .controlSize(.small)
                #endif
            Text("加载中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("加载失败")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("重试") {
                Task {
                    await store.fetch()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func content(_ detail: NovelSeriesDetail) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            seriesHeader(detail)

            Divider()

            if !store.novels.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("小说列表")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    novelList
                }
            }
        }
        .padding()
    }

    private func seriesHeader(_ detail: NovelSeriesDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TranslatableText(text: detail.title, font: .title2)
                .fontWeight(.bold)

            if let caption = detail.caption, !caption.isEmpty {
                TranslatableText(
                    text: caption,
                    font: .body
                )
                .foregroundColor(.secondary)
                .lineSpacing(4)
            }

            HStack(spacing: 16) {
                if detail.isConcluded {
                    Label("已完结", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("连载中", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Label("\(detail.contentCount)章", systemImage: "doc.text.fill")
                    .font(.caption)

                Label("\(formatCharacterCount(detail.totalCharacterCount))", systemImage: "character.book.closed")
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            if let latestNovel = store.novels.first {
                NavigationLink(value: latestNovel) {
                    Label("查看最新章节", systemImage: "arrow.right.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
    }

    private var novelList: some View {
        VStack(spacing: 12) {
            ForEach(Array(store.novels.enumerated()), id: \.element.id) { index, novel in
                NavigationLink(value: novel) {
                    NovelSeriesCard(novel: novel, index: index)
                }

                if index < store.novels.count - 1 {
                    Divider()
                }

                if index == store.novels.count - 1 && store.nextUrl != nil && !store.isLoadingMore {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            Task {
                                await store.loadMore()
                            }
                        }
                }
            }

            if store.isLoadingMore {
                HStack {
                    ProgressView()
                        #if os(macOS)
                        .controlSize(.small)
                        #endif
                    Text("加载中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }

    private func formatCharacterCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1f万字", Double(count) / 10000)
        } else if count >= 1000 {
            return String(format: "%.1f千字", Double(count) / 1000)
        }
        return "\(count)字"
    }

    private func exportSeries(format: NovelExportFormat) {
        guard !isExporting, let detail = store.seriesDetail else { return }
        isExporting = true
        currentExportFormat = format
        exportProgress = 0

        Task {
            do {
                var novelsWithContent: [(novel: Novel, content: NovelReaderContent)] = []
                let totalNovels = store.novels.count

                // 1. 下载所有小说内容
                for (index, novel) in store.novels.enumerated() {
                    let content = try await PixivAPI.shared.getNovelContent(novelId: novel.id)
                    novelsWithContent.append((novel: novel, content: content))

                    await MainActor.run {
                        exportProgress = Double(index + 1) / Double(totalNovels) * 0.5  // 50% for downloading
                    }
                }

                // 2. 生成导出文件
                let filename = NovelExporter.buildFilename(
                    novelId: seriesId,
                    title: detail.title,
                    authorName: detail.user.name,
                    format: format,
                    isSeries: true
                )

                let data: Data
                switch format {
                case .txt:
                    data = try await NovelExporter.exportSeriesAsTXT(
                        seriesId: seriesId,
                        seriesTitle: detail.title,
                        authorName: detail.user.name,
                        novels: novelsWithContent
                    )
                case .epub:
                    data = try await NovelExporter.exportSeriesAsEPUB(
                        seriesId: seriesId,
                        seriesTitle: detail.title,
                        authorName: detail.user.name,
                        novels: novelsWithContent
                    )
                }

                await MainActor.run {
                    exportProgress = 0.8  // 80% done
                }

                // 3. 保存文件
                #if os(iOS)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try data.write(to: tempURL)

                await MainActor.run {
                    exportTempURL = tempURL
                    exportFilename = filename
                    exportProgress = 1.0
                    isExporting = false
                    showDocumentPicker = true
                }
                #else
                // macOS: 显示保存面板
                let panel = NSSavePanel()
                switch format {
                case .txt:
                    panel.allowedContentTypes = [.plainText]
                case .epub:
                    panel.allowedContentTypes = [UTType(filenameExtension: "epub")!]
                }
                panel.nameFieldStringValue = filename
                panel.title = String(localized: "导出系列")

                let result = await withCheckedContinuation { continuation in
                    panel.begin { response in
                        continuation.resume(returning: response)
                    }
                }

                if result == .OK, let url = panel.url {
                    try data.write(to: url)
                }

                await MainActor.run {
                    isExporting = false
                    showExportToast = true
                }
                #endif

            } catch {
                print("[NovelSeriesView] 导出系列失败: \(error)")
                await MainActor.run {
                    isExporting = false
                    exportProgress = 0
                }
            }
        }
    }

    private func shareSeries() {
        guard let detail = store.seriesDetail else { return }
        guard let url = URL(string: "https://www.pixiv.net/novel/series/\(detail.id)") else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}

#Preview {
    NavigationStack {
        NovelSeriesView(seriesId: 1)
    }
}

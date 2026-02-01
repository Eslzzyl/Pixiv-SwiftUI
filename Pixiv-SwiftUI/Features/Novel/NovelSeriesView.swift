import SwiftUI
import TranslationKit
import UniformTypeIdentifiers

struct NovelSeriesView: View {
    let seriesId: Int
    @State private var store: NovelSeriesStore
    @State private var showExportToast = false
    @State private var showDocumentPicker = false
    @State private var exportTempURL: URL?
    @State private var exportFilename: String = ""
    @State private var showingExportAlert = false
    @State private var isLoadingForExport = false
    @State private var selectedExportFormat: NovelExportFormat = .txt

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
        .navigationTitle(store.seriesDetail?.title ?? String(localized: "系列详情"))
        .id("SeriesScrollView-\(seriesId)")  // 添加稳定的 ID
        .onAppear {
            print("[NovelSeriesView] onAppear - seriesId: \(seriesId)")
        }
        .refreshable {
            await store.fetch()
        }
        .keyboardShortcut("r", modifiers: .command)
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
        .alert("导出系列", isPresented: $showingExportAlert) {
            Button("保存到默认位置", action: startExportToDownloadQueue)
            Button("取消", role: .cancel) {}
        } message: {
            Text("选择导出方式")
        }
        #else
        .alert("导出系列", isPresented: $showingExportAlert) {
            Button("导出", action: startExportToDownloadQueueWithDialog)
            Button("取消", role: .cancel) {}
        } message: {
            Text("确认导出系列为\(selectedExportFormat.rawValue.uppercased())格式")
        }
        #endif
        .toolbar {
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
                #if os(macOS)
                .buttonStyle(.plain)
                #endif
            }
        }
    }

    private var novelList: some View {
        VStack(spacing: 12) {
            ForEach(Array(store.novels.enumerated()), id: \.element.id) { index, novel in
                NavigationLink(value: novel) {
                    NovelSeriesCard(novel: novel, index: index)
                }
                #if os(macOS)
                .buttonStyle(.plain)
                #endif

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
        guard let detail = store.seriesDetail else { return }

        selectedExportFormat = format
        showingExportAlert = true
    }

    private func startExportToDownloadQueue() {
        guard let detail = store.seriesDetail else { return }

        isLoadingForExport = true

        Task {
            do {
                // 加载所有剩余章节（如果还有未加载的）
                while store.nextUrl != nil {
                    await store.loadMore()
                }

                print("[NovelSeriesView] 已加载完整系列，共 \(store.novels.count) 章")

                // 添加导出任务到下载队列
                await DownloadStore.shared.addNovelSeriesTask(
                    seriesId: seriesId,
                    seriesTitle: detail.title,
                    authorName: detail.user.name,
                    novels: store.novels,
                    format: selectedExportFormat,
                    customSaveURL: nil
                )

                await MainActor.run {
                    isLoadingForExport = false
                    showExportToast = true
                    showingExportAlert = false
                }

                print("[NovelSeriesView] 系列导出任务已添加到下载队列")
            } catch {
                print("[NovelSeriesView] 加载系列数据失败: \(error)")
                await MainActor.run {
                    isLoadingForExport = false
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

    private func exportToCustomLocation(_ url: URL) {
        guard let detail = store.seriesDetail else { return }

        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        isLoadingForExport = true

        Task {
            do {
                // 加载所有剩余章节（如果还有未加载的）
                while store.nextUrl != nil {
                    await store.loadMore()
                }

                print("[NovelSeriesView] 已加载完整系列，共 \(store.novels.count) 章")

                // 添加导出任务到下载队列（指定自定义保存位置）
                await DownloadStore.shared.addNovelSeriesTask(
                    seriesId: seriesId,
                    seriesTitle: detail.title,
                    authorName: detail.user.name,
                    novels: store.novels,
                    format: selectedExportFormat,
                    customSaveURL: url
                )

                await MainActor.run {
                    isLoadingForExport = false
                    showExportToast = true
                    showingExportAlert = false
                }

                print("[NovelSeriesView] 系列导出任务已添加到下载队列（自定义位置）")
            } catch {
                print("[NovelSeriesView] 加载系列数据失败: \(error)")
                await MainActor.run {
                    isLoadingForExport = false
                }
            }
        }
    }

    private func startExportToDownloadQueueWithDialog() {
        #if os(macOS)
        guard let detail = store.seriesDetail else { return }

        isLoadingForExport = true

        Task {
            do {
                // 加载所有剩余章节（如果还有未加载的）
                while store.nextUrl != nil {
                    await store.loadMore()
                }

                print("[NovelSeriesView] 已加载完整系列，共 \(store.novels.count) 章")

                // 在 macOS 上，先显示保存对话框让用户选择位置
                let filename = NovelExporter.buildFilename(
                    novelId: seriesId,
                    title: detail.title,
                    authorName: detail.user.name,
                    format: selectedExportFormat,
                    isSeries: true
                )

                let panel = NSSavePanel()
                switch selectedExportFormat {
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
                    // 用户选择了保存位置，添加任务
                    await DownloadStore.shared.addNovelSeriesTask(
                        seriesId: seriesId,
                        seriesTitle: detail.title,
                        authorName: detail.user.name,
                        novels: store.novels,
                        format: selectedExportFormat,
                        customSaveURL: url
                    )

                    await MainActor.run {
                        showExportToast = true
                    }
                }

                await MainActor.run {
                    isLoadingForExport = false
                    showingExportAlert = false
                }
            } catch {
                print("[NovelSeriesView] 处理失败: \(error)")
                await MainActor.run {
                    isLoadingForExport = false
                }
            }
        }
        #endif
    }
}

#Preview {
    NavigationStack {
        NovelSeriesView(seriesId: 1)
    }
}

import SwiftUI
import Kingfisher
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// 已删除作品详情页
struct DeletedBookmarkDetailView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(\.dismiss) private var dismiss

    let cache: BookmarkCache

    @State private var illust: Illusts?
    @State private var currentPage = 0
    @State private var showRemoveConfirmation = false
    @State private var showExportSheet = false
    @State private var showCopyToast = false
    @State private var isSaving = false
    @State private var showSaveToast = false

    private var accountStore: AccountStore { AccountStore.shared }
    private var bookmarkCacheStore: BookmarkCacheStore { BookmarkCacheStore.shared }

    private var imageURLs: [String] {
        guard let illust = illust else { return [] }
        let quality = userSettingStore.userSetting.pictureQuality

        if !illust.metaPages.isEmpty {
            return illust.metaPages.indices.compactMap { index in
                ImageURLHelper.getPageImageURL(from: illust, page: index, quality: quality)
            }
        }
        return [ImageURLHelper.getImageURL(from: illust, quality: quality)]
    }

    var body: some View {
        Group {
            if let illust = illust {
                illustContent(illust)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("无法加载作品数据")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(illust?.title ?? "已删除作品")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Button {
                        exportIllust()
                    } label: {
                        Label("导出作品", systemImage: "square.and.arrow.up")
                    }

                    if let illust = illust {
                        Button {
                            copyId(illust.id)
                        } label: {
                            Label("复制作品ID", systemImage: "doc.on.doc")
                        }

                        if let url = URL(string: "https://www.pixiv.net/artworks/\(illust.id)") {
                            ShareLink(item: url) {
                                Label("分享链接", systemImage: "link")
                            }
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showRemoveConfirmation = true
                    } label: {
                        Label("从缓存中移除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            illust = cache.getIllust()
        }
        .confirmationDialog("从缓存中移除", isPresented: $showRemoveConfirmation, titleVisibility: .visible) {
            Button("移除", role: .destructive) {
                bookmarkCacheStore.removeCache(illustId: cache.illustId, ownerId: cache.ownerId)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除此作品的缓存数据和图片，此操作不可恢复。")
        }
        .overlay(alignment: .bottom) {
            if showCopyToast {
                toastView(message: "已复制")
            }
            if showSaveToast {
                toastView(message: "保存成功")
            }
        }
    }

    @ViewBuilder
    private func illustContent(_ illust: Illusts) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                deletedBanner

                imageSection(illust)

                infoSection(illust)
            }
        }
    }

    private var deletedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text("此作品已被作者删除")
                .foregroundStyle(.white)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.red)
    }

    @ViewBuilder
    private func imageSection(_ illust: Illusts) -> some View {
        if imageURLs.count > 1 {
            TabView(selection: $currentPage) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, urlString in
                    cachedImage(urlString: urlString, aspectRatio: illust.safeAspectRatio)
                        .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            #endif
            .frame(height: 400)
        } else if let urlString = imageURLs.first {
            cachedImage(urlString: urlString, aspectRatio: illust.safeAspectRatio)
        }
    }

    @ViewBuilder
    private func cachedImage(urlString: String, aspectRatio: CGFloat) -> some View {
        KFImage(URL(string: urlString))
            .setProcessor(DefaultImageProcessor.default)
            .cacheOriginalImage()
            .targetCache(BookmarkCacheService.shared.getCache())
            .requestModifier(PixivImageRequestModifier())
            .placeholder {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(aspectRatio, contentMode: .fit)
            }
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    @ViewBuilder
    private func infoSection(_ illust: Illusts) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(illust.title)
                .font(.title2)
                .fontWeight(.bold)

            HStack {
                CachedAsyncImage(urlString: illust.user.profileImageUrls?.medium, idealWidth: 40)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                VStack(alignment: .leading) {
                    Text(illust.user.name)
                        .fontWeight(.medium)
                    Text("@\(illust.user.account)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !illust.caption.isEmpty {
                Text(illust.caption.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            FlowLayout(spacing: 8) {
                ForEach(illust.tags, id: \.name) { tag in
                    Text("#\(tag.translatedName ?? tag.name)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("\(illust.totalView)", systemImage: "eye")
                    Spacer()
                    Label("\(illust.totalBookmarks)", systemImage: "heart")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text("创建于 \(formatDate(illust.createDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("尺寸: \(illust.width) × \(illust.height)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if illust.pageCount > 1 {
                    Text("页数: \(illust.pageCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 16) {
                Button {
                    exportIllust()
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)

                Button(role: .destructive) {
                    showRemoveConfirmation = true
                } label: {
                    Label("移除缓存", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }

    private func copyId(_ id: Int) {
        #if os(iOS)
        UIPasteboard.general.string = String(id)
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(String(id), forType: .string)
        #endif
        showCopyToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopyToast = false
        }
    }

    private func exportIllust() {
        guard let illust = illust else { return }
        isSaving = true

        Task {
            do {
                let quality = userSettingStore.userSetting.downloadQuality
                let urls = getExportURLs(illust: illust, quality: quality)

                for (index, urlString) in urls.enumerated() {
                    guard let url = URL(string: urlString) else { continue }

                    let image = try await KingfisherManager.shared.retrieveImage(
                        with: .network(KF.ImageResource(downloadURL: url)),
                        options: BookmarkCacheService.shared.cacheOptions()
                    )

                    #if os(iOS)
                    UIImageWriteToSavedPhotosAlbum(image.image, nil, nil, nil)
                    #elseif os(macOS)
                    let savePanel = NSSavePanel()
                    savePanel.allowedContentTypes = [.png]
                    savePanel.nameFieldStringValue = "\(illust.id)_p\(index).png"

                    if savePanel.runModal() == .OK, let saveURL = savePanel.url {
                        if let pngData = image.image.pngData() {
                            try pngData.write(to: saveURL)
                        }
                    }
                    #endif
                }

                await MainActor.run {
                    isSaving = false
                    showSaveToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showSaveToast = false
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
                print("[DeletedBookmarkDetailView] 导出失败: \(error)")
            }
        }
    }

    private func getExportURLs(illust: Illusts, quality: Int) -> [String] {
        if !illust.metaPages.isEmpty {
            return illust.metaPages.indices.compactMap { index in
                ImageURLHelper.getPageImageURL(from: illust, page: index, quality: quality)
            }
        }
        return [ImageURLHelper.getImageURL(from: illust, quality: quality)]
    }

    @ViewBuilder
    private func toastView(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut, value: showCopyToast || showSaveToast)
    }
}

#if os(macOS)
extension NSImage {
    func pngData() -> Data? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
#endif

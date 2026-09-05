import SwiftUI
import Kingfisher
import os.log

struct NovelSpanRenderer: View {
    let span: NovelSpan
    let store: NovelReaderStore
    let paragraphIndex: Int
    let onImageTap: (Int) -> Void
    let onLinkTap: (String) -> Void
    @Environment(ThemeManager.self) var themeManager

    var body: some View {
        Group {
            switch span.type {
            case .normal:
                normalTextView
            case .newPage:
                newPageView
            case .chapter:
                chapterView
            case .pixivImage:
                pixivImageView
            case .uploadedImage:
                uploadedImageView
            case .jumpUri:
                jumpUriView
            case .rubyText:
                rubyTextView
            }
        }
    }

    @ViewBuilder
    private var normalTextView: some View {
        let cleanText = span.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanText.isEmpty {
            EmptyView()
        } else {
            let paragraphSpacing = store.settings.fontSize * (store.settings.lineHeight - 1) + 8

            BilingualParagraph(
                original: cleanText,
                translated: store.translatedParagraphs[paragraphIndex],
                isTranslating: store.translatingIndices.contains(paragraphIndex),
                showTranslation: store.isTranslationEnabled,
                fontSize: store.settings.fontSize,
                lineHeight: store.settings.lineHeight,
                fontFamily: store.settings.fontFamily,
                textColor: textColor,
                displayMode: store.settings.translationDisplayMode,
                firstLineIndent: store.settings.firstLineIndent
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, paragraphSpacing / 2)
            .onTapGesture {
                Task {
                    await store.translateParagraph(paragraphIndex, text: span.content)
                }
            }
        }
    }

    @ViewBuilder
    private var newPageView: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 30)
            Divider()
            Spacer()
                .frame(height: 30)
        }
    }

    @ViewBuilder
    private var chapterView: some View {
        Text(span.content)
            .font(store.settings.fontFamily.font(size: store.settings.fontSize + 2, weight: .bold))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
    }

    @ViewBuilder
    private var pixivView: some View {
        EmptyView()
    }

    @ViewBuilder
    private var pixivImageView: some View {
        Group {
            if let metadata = span.metadata,
               let illustId = metadata["illustId"] as? Int,
               let imageUrl = metadata["imageUrl"] as? String,
               !imageUrl.isEmpty,
               let imageURL = URL(string: imageUrl) {
                VStack(spacing: 8) {
                    novelImageView(
                        imageURL: imageURL,
                        logContext: "pixivImage spanId=\(span.id) illustId=\(illustId)"
                    )
                        .onTapGesture {
                            onImageTap(illustId)
                        }

                    Text("点击查看大图")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            } else {
                Text("[图片加载失败]")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    private var uploadedImageView: some View {
        Group {
            if let metadata = span.metadata,
               let imageKey = metadata["imageKey"] as? String,
               let imageUrl = metadata["imageUrl"] as? String,
               !imageUrl.isEmpty,
               let imageURL = URL(string: imageUrl) {
                novelImageView(
                    imageURL: imageURL,
                    logContext: "uploadedImage spanId=\(span.id) imageKey=\(imageKey)"
                )
                    .padding(.vertical, 8)
            } else {
                Text("[图片加载失败]")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    @ViewBuilder
    private func novelImageView(imageURL: URL, logContext: String) -> some View {
        if shouldUseDirectConnection(url: imageURL) {
            KFImage.source(.directNetwork(imageURL))
                .fade(duration: 0.3)
                .onSuccess { result in
                    Logger.novel.info("\(logContext) 加载成功: url=\(imageURL.absoluteString), cache=\(String(describing: result.cacheType)), size=\(Int(result.image.size.width))x\(Int(result.image.size.height))")
                }
                .onFailure { error in
                    Logger.novel.warning("加载失败: url=\(imageURL.absoluteString), error=\(error)")
                }
                .placeholder {
                    ProgressView()
                }
                .resizable()
                .scaledToFit()
                .cornerRadius(8)
                .onAppear {
                    logImageLoadStart(imageURL: imageURL, logContext: logContext, directConnection: true)
                }
        } else {
            KFImage(imageURL)
                .fade(duration: 0.3)
                .requestModifier(PixivImageLoader.shared)
                .onSuccess { result in
                    Logger.novel.info("\(logContext) 加载成功: url=\(imageURL.absoluteString), cache=\(String(describing: result.cacheType)), size=\(Int(result.image.size.width))x\(Int(result.image.size.height))")
                }
                .onFailure { error in
                    Logger.novel.warning("加载失败: url=\(imageURL.absoluteString), error=\(error)")
                }
                .placeholder {
                    ProgressView()
                }
                .resizable()
                .scaledToFit()
                .cornerRadius(8)
                .onAppear {
                    logImageLoadStart(imageURL: imageURL, logContext: logContext, directConnection: false)
                }
        }
    }

    private func shouldUseDirectConnection(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return NetworkModeStore.shared.useDirectConnection &&
            (host.contains("i.pximg.net") || host.contains("img-master.pixiv.net"))
    }

    private func logImageLoadStart(imageURL: URL, logContext: String, directConnection: Bool) {
        let host = imageURL.host ?? "nil"
        Logger.novel.debug("\(logContext) 开始加载: url=\(imageURL.absoluteString), host=\(host), direct=\(directConnection)")
    }

    private var jumpUriView: some View {
        Group {
            if let metadata = span.metadata,
               let url = metadata["url"] as? String {
                Text(span.content)
                    .font(.system(size: store.settings.fontSize))
                    .foregroundColor(themeManager.currentColor)
                    .underline()
                    .onTapGesture {
                        onLinkTap(url)
                    }
            } else {
                Text(span.content)
                    .font(.system(size: store.settings.fontSize))
                    .foregroundColor(textColor)
            }
        }
    }

    private var rubyTextView: some View {
        Group {
            if let metadata = span.metadata,
               let baseText = metadata["baseText"] as? String,
               let rubyText = metadata["rubyText"] as? String {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(baseText)
                        .font(store.settings.fontFamily.font(size: store.settings.fontSize))
                    Text(rubyText)
                        .font(store.settings.fontFamily.font(size: store.settings.fontSize * 0.6))
                        .foregroundColor(.secondary)
                }
                .foregroundColor(textColor)
            } else {
                Text(span.content)
                    .font(store.settings.fontFamily.font(size: store.settings.fontSize))
                    .foregroundColor(textColor)
            }
        }
    }

    private var textColor: Color {
        switch store.settings.theme {
        case .light, .sepia:
            return .black
        case .dark:
            return .white
        case .system:
            return colorScheme == .dark ? .white : .black
        }
    }

    @Environment(\.colorScheme) private var colorScheme
}

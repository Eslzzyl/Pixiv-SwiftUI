import SwiftUI
import Kingfisher

struct NovelSpanRenderer: View {
    let span: NovelSpan
    let store: NovelReaderStore
    let paragraphIndex: Int
    let onImageTap: (Int) -> Void
    let onLinkTap: (String) -> Void

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

    private var normalTextView: some View {
        let cleanText = span.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return EmptyView().eraseToAnyView() }

        let paragraphSpacing = store.settings.fontSize * (store.settings.lineHeight - 1) + 8

        return BilingualParagraph(
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
        .eraseToAnyView()
    }

    private var newPageView: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 30)
            Divider()
            Spacer()
                .frame(height: 30)
        }
        .eraseToAnyView()
    }

    private var chapterView: some View {
        Text(span.content)
            .font(store.settings.fontFamily.font(size: store.settings.fontSize + 2, weight: .bold))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
        .eraseToAnyView()
    }

    private var pixivView: some View {
        EmptyView().eraseToAnyView()
    }

    private var pixivImageView: some View {
        Group {
            if let metadata = span.metadata,
               let illustId = metadata["illustId"] as? Int,
               let imageUrl = metadata["imageUrl"] as? String {
                VStack(spacing: 8) {
                    KFImage(URL(string: imageUrl))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
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
        .eraseToAnyView()
    }

    private var uploadedImageView: some View {
        Group {
            if let metadata = span.metadata,
               let imageUrl = metadata["imageUrl"] as? String {
                KFImage(URL(string: imageUrl))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
                    .padding(.vertical, 8)
            } else {
                Text("[图片加载失败]")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .eraseToAnyView()
    }

    private var jumpUriView: some View {
        Group {
            if let metadata = span.metadata,
               let url = metadata["url"] as? String {
                Text(span.content)
                    .font(.system(size: store.settings.fontSize))
                    .foregroundColor(.blue)
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
        .eraseToAnyView()
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
        .eraseToAnyView()
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

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

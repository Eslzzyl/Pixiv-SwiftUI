import SwiftUI
import Kingfisher

struct NovelSpanRenderer: View {
    let span: NovelSpan
    let store: NovelReaderStore
    let paragraphIndex: Int
    let onImageTap: (Int) -> Void
    let onLinkTap: (String) -> Void

    private var isVisible: Bool {
        store.isParagraphVisible(paragraphIndex)
    }

    private var effectiveFontSize: CGFloat {
        isVisible ? store.settings.fontSize : cachedFontSize
    }

    private var effectiveLineHeight: CGFloat {
        isVisible ? store.settings.lineHeight : cachedLineHeight
    }

    @State private var cachedFontSize: CGFloat = 16
    @State private var cachedLineHeight: CGFloat = 1.8

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
        .onChange(of: store.settings.fontSize) { _, newValue in
            if isVisible {
                cachedFontSize = newValue
            }
        }
        .onChange(of: store.settings.lineHeight) { _, newValue in
            if isVisible {
                cachedLineHeight = newValue
            }
        }
        .onChange(of: isVisible) { _, newIsVisible in
            if newIsVisible {
                cachedFontSize = store.settings.fontSize
                cachedLineHeight = store.settings.lineHeight
            }
        }
    }

    private var normalTextView: some View {
        let cleanText = span.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return EmptyView().eraseToAnyView() }

        return BilingualParagraph(
            original: cleanText,
            translated: store.translatedParagraphs[paragraphIndex],
            isTranslating: store.translatingIndices.contains(paragraphIndex),
            fontSize: effectiveFontSize,
            lineHeight: effectiveLineHeight,
            textColor: textColor
        )
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
            .font(.system(size: effectiveFontSize + 2, weight: .bold))
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
                    .font(.system(size: effectiveFontSize))
                    .foregroundColor(.blue)
                    .underline()
                    .onTapGesture {
                        onLinkTap(url)
                    }
            } else {
                Text(span.content)
                    .font(.system(size: effectiveFontSize))
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
                        .font(.system(size: effectiveFontSize))
                    Text(rubyText)
                        .font(.system(size: effectiveFontSize * 0.6))
                        .foregroundColor(.secondary)
                }
                .foregroundColor(textColor)
            } else {
                Text(span.content)
                    .font(.system(size: effectiveFontSize))
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

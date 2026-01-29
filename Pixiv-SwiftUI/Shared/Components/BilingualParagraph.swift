import SwiftUI

struct BilingualParagraph: View {
    let original: String
    let translated: String?
    let isTranslating: Bool
    let showTranslation: Bool
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let fontFamily: ReaderFontFamily
    let textColor: Color
    let displayMode: TranslationDisplayMode
    let firstLineIndent: Bool

    @State private var isExpanded = false

    init(
        original: String,
        translated: String?,
        isTranslating: Bool,
        showTranslation: Bool,
        fontSize: CGFloat,
        lineHeight: CGFloat,
        fontFamily: ReaderFontFamily = .default,
        textColor: Color,
        displayMode: TranslationDisplayMode,
        firstLineIndent: Bool
    ) {
        self.original = original
        self.translated = translated
        self.isTranslating = isTranslating
        self.showTranslation = showTranslation
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.fontFamily = fontFamily
        self.textColor = textColor
        self.displayMode = displayMode
        self.firstLineIndent = firstLineIndent
    }

    private var translatedFontSize: CGFloat {
        displayMode == .bilingual ? fontSize - 1 : fontSize
    }

    private var translatedTextColor: Color {
        displayMode == .bilingual ? textColor.opacity(0.8) : textColor
    }

    private var indentPrefix: String {
        firstLineIndent ? "\u{3000}\u{3000}" : ""
    }

    private var indentSize: CGFloat {
        firstLineIndent ? fontSize * 2 : 0
    }

    var body: some View {
        Group {
            if displayMode == .bilingual {
                Text(indentPrefix + original)
                    .font(fontFamily.font(size: fontSize))
                    .lineSpacing(fontSize * (lineHeight - 1))
                    .foregroundColor(textColor)
                    .textSelection(.enabled)
            }

            Group {
                if displayMode == .translationOnly {
                    translationOnlyView
                } else {
                    bilingualTranslationView
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if showTranslation && displayMode == .bilingual {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
    }

    @ViewBuilder
    private var translationOnlyView: some View {
        if let translated = translated {
            Text(indentPrefix + translated)
                .font(fontFamily.font(size: fontSize))
                .lineSpacing(fontSize * (lineHeight - 1))
                .foregroundColor(textColor)
                .textSelection(.enabled)
        } else if isTranslating {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("翻译中...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, indentSize)
        } else {
            Text(indentPrefix + original)
                .font(fontFamily.font(size: fontSize))
                .lineSpacing(fontSize * (lineHeight - 1))
                .foregroundColor(textColor)
                .textSelection(.enabled)

            if showTranslation && translated == nil {
                expandHint
            }
        }
    }

    @ViewBuilder
    private var bilingualTranslationView: some View {
        if showTranslation && (isExpanded || translated != nil || isTranslating) {
            translatedView
        }

        if showTranslation && translated == nil && !isTranslating {
            expandHint
        }
    }

    @ViewBuilder
    private var translatedView: some View {
        if let translated = translated {
            Text(indentPrefix + translated)
                .font(fontFamily.font(size: translatedFontSize))
                .lineSpacing(translatedFontSize * (lineHeight - 1))
                .foregroundColor(translatedTextColor)
                .textSelection(.enabled)
                .padding(.top, displayMode == .bilingual ? 8 : 0)
        } else if isTranslating {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("翻译中...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, indentSize)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var expandHint: some View {
        HStack(spacing: 4) {
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
            Text("点击展开翻译")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
            Spacer()
        }
        .padding(.top, 2)
    }
}

#Preview("Translation Only 模式") {
    VStack(spacing: 20) {
        BilingualParagraph(
            original: "这是一个测试段落，用于展示双语排版效果。",
            translated: "This is a test paragraph to demonstrate bilingual layout effects.",
            isTranslating: false,
            showTranslation: true,
            fontSize: 16,
            lineHeight: 1.8,
            textColor: .black,
            displayMode: .translationOnly,
            firstLineIndent: true
        )

        BilingualParagraph(
            original: "这是另一段文字，只有原文没有翻译。",
            translated: nil,
            isTranslating: false,
            showTranslation: true,
            fontSize: 16,
            lineHeight: 1.8,
            textColor: .black,
            displayMode: .translationOnly,
            firstLineIndent: true
        )

        BilingualParagraph(
            original: "翻訳中のテキストです。",
            translated: nil,
            isTranslating: true,
            showTranslation: true,
            fontSize: 16,
            lineHeight: 1.8,
            textColor: .black,
            displayMode: .translationOnly,
            firstLineIndent: true
        )
    }
    .padding()
}

#Preview("Bilingual 模式") {
    VStack(spacing: 20) {
        BilingualParagraph(
            original: "这是一个测试段落，用于展示双语排版效果。",
            translated: "This is a test paragraph to demonstrate bilingual layout effects.",
            isTranslating: false,
            showTranslation: true,
            fontSize: 16,
            lineHeight: 1.8,
            textColor: .black,
            displayMode: .bilingual,
            firstLineIndent: true
        )

        BilingualParagraph(
            original: "这是另一段文字，只有原文没有翻译。",
            translated: nil,
            isTranslating: false,
            showTranslation: true,
            fontSize: 16,
            lineHeight: 1.8,
            textColor: .black,
            displayMode: .bilingual,
            firstLineIndent: true
        )

        BilingualParagraph(
            original: "翻訳中のテキストです。",
            translated: nil,
            isTranslating: true,
            showTranslation: true,
            fontSize: 16,
            lineHeight: 1.8,
            textColor: .black,
            displayMode: .bilingual,
            firstLineIndent: true
        )
    }
    .padding()
}

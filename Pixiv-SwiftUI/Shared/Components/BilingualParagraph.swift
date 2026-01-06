import SwiftUI

struct BilingualParagraph: View {
    let original: String
    let translated: String?
    let isTranslating: Bool
    let showTranslation: Bool
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let textColor: Color

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(original)
                .font(.system(size: fontSize))
                .lineSpacing(fontSize * (lineHeight - 1))
                .foregroundColor(textColor)
                .textSelection(.enabled)

            if showTranslation && (isExpanded || translated != nil || isTranslating) {
                translatedView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showTranslation && translated == nil && !isTranslating {
                expandHint
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if showTranslation {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
    }

    @ViewBuilder
    private var translatedView: some View {
        if let translated = translated {
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 3)
                    .cornerRadius(1.5)

                Text(translated)
                    .font(.system(size: fontSize - 1))
                    .lineSpacing((fontSize - 1) * (lineHeight - 1))
                    .foregroundColor(textColor.opacity(0.8))
                    .textSelection(.enabled)
            }
            .padding(.top, 4)
        } else if isTranslating {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("翻译中...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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

#Preview {
    VStack(spacing: 20) {
        BilingualParagraph(
            original: "这是一个测试段落，用于展示双语排版效果。",
            translated: "This is a test paragraph to demonstrate bilingual layout effects.",
            isTranslating: false,
            showTranslation: true,
            fontSize: 16,
            lineHeight: 1.8,
            textColor: .black
        )

        BilingualParagraph(
            original: "这是另一段文字，只有原文没有翻译。",
            translated: nil,
            isTranslating: false,
            showTranslation: true,
            fontSize: 16,
            lineHeight: 1.8,
            textColor: .black
        )

        BilingualParagraph(
            original: "翻訳中のテキストです。",
            translated: nil,
            isTranslating: true,
            showTranslation: true,
            fontSize: 16,
            lineHeight: 1.8,
            textColor: .black
        )
    }
    .padding()
}

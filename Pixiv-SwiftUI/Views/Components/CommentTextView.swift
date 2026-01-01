import SwiftUI

/// 支持 Pixiv 表情的评论文本视图
struct CommentTextView: View {
    let text: String
    let font: Font
    let color: Color
    
    init(_ text: String, font: Font = .body, color: Color = .primary) {
        self.text = text
        self.font = font
        self.color = color
    }
    
    var body: some View {
        parseText(text)
            .font(font)
            .foregroundColor(color)
    }
    
    private func parseText(_ text: String) -> Text {
        var parts: [Text] = []
        var currentText = ""
        var isCollectingEmoji = false
        var emojiBuffer = ""

        for char in text {
            if char == "(" {
                if isCollectingEmoji {
                    parts.append(Text(emojiBuffer))
                } else if !currentText.isEmpty {
                    parts.append(Text(currentText))
                    currentText = ""
                }
                isCollectingEmoji = true
                emojiBuffer = "("
            } else if char == ")" && isCollectingEmoji {
                emojiBuffer.append(char)
                if let imageName = EmojiHelper.getEmojiImageName(for: emojiBuffer) {
                    #if canImport(UIKit)
                    if let uiImage = UIImage(named: imageName) {
                        let targetSize = CGSize(width: uiImage.size.width * 0.5, height: uiImage.size.height * 0.5)
                        let renderer = UIGraphicsImageRenderer(size: targetSize)
                        let resizedImage = renderer.image { _ in
                            uiImage.draw(in: CGRect(origin: .zero, size: targetSize))
                        }
                        parts.append(Text(Image(uiImage: resizedImage)).baselineOffset(-2))
                    } else {
                        parts.append(Text(emojiBuffer))
                    }
                    #else
                    if let nsImage = NSImage(named: imageName) {
                        let targetSize = NSSize(width: nsImage.size.width * 0.5, height: nsImage.size.height * 0.5)
                        let resizedImage = NSImage(size: targetSize)
                        resizedImage.lockFocus()
                        nsImage.draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1.0)
                        resizedImage.unlockFocus()
                        parts.append(Text(Image(nsImage: resizedImage)).baselineOffset(-2))
                    } else {
                        parts.append(Text(emojiBuffer))
                    }
                    #endif
                } else {
                    parts.append(Text(emojiBuffer))
                }
                isCollectingEmoji = false
                emojiBuffer = ""
            } else {
                if isCollectingEmoji {
                    emojiBuffer.append(char)
                    if emojiBuffer.count > 20 {
                        parts.append(Text(emojiBuffer))
                        isCollectingEmoji = false
                        emojiBuffer = ""
                    }
                } else {
                    currentText.append(char)
                }
            }
        }

        if isCollectingEmoji {
            parts.append(Text(emojiBuffer))
        }

        if !currentText.isEmpty {
            parts.append(Text(currentText))
        }

        return parts.reduce(Text("")) { $0 + $1 }
    }


}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        CommentTextView("这是一个测试 (happy) 带有表情的评论 (blush)")
        CommentTextView("多个表情连在一起 (love2)(love2)(love2)")
        CommentTextView("未闭合的括号 (normal")
        CommentTextView("不存在的表情 (not_exist)")
    }
    .padding()
}

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
        var result = Text("")
        var currentText = ""
        var isCollectingEmoji = false
        var emojiBuffer = ""
        
        for char in text {
            if char == "(" {
                if isCollectingEmoji {
                    // 如果已经在收集表情又遇到 (，说明之前的 ( 只是普通文本
                    result = result + Text(emojiBuffer)
                } else if !currentText.isEmpty {
                    result = result + Text(currentText)
                    currentText = ""
                }
                isCollectingEmoji = true
                emojiBuffer = "("
            } else if char == ")" && isCollectingEmoji {
                emojiBuffer.append(char)
                if let imageName = EmojiHelper.getEmojiImageName(for: emojiBuffer) {
                    #if canImport(UIKit)
                    if let uiImage = UIImage(named: imageName) {
                        // 缩小到一半大小 (假设原始大小约为 40-50pt，缩小到 20pt 左右)
                        let targetSize = CGSize(width: uiImage.size.width * 0.5, height: uiImage.size.height * 0.5)
                        let renderer = UIGraphicsImageRenderer(size: targetSize)
                        let resizedImage = renderer.image { _ in
                            uiImage.draw(in: CGRect(origin: .zero, size: targetSize))
                        }
                        result = result + Text(Image(uiImage: resizedImage)).baselineOffset(-2)
                    } else {
                        result = result + Text(emojiBuffer)
                    }
                    #else
                    if let nsImage = NSImage(named: imageName) {
                        let targetSize = NSSize(width: nsImage.size.width * 0.5, height: nsImage.size.height * 0.5)
                        let resizedImage = NSImage(size: targetSize)
                        resizedImage.lockFocus()
                        nsImage.draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1.0)
                        resizedImage.unlockFocus()
                        result = result + Text(Image(nsImage: resizedImage)).baselineOffset(-2)
                    } else {
                        result = result + Text(emojiBuffer)
                    }
                    #endif
                } else {
                    result = result + Text(emojiBuffer)
                }
                isCollectingEmoji = false
                emojiBuffer = ""
            } else {
                if isCollectingEmoji {
                    emojiBuffer.append(char)
                    // 如果 buffer 太长，可能不是表情，回退
                    if emojiBuffer.count > 20 {
                        result = result + Text(emojiBuffer)
                        isCollectingEmoji = false
                        emojiBuffer = ""
                    }
                } else {
                    currentText.append(char)
                }
            }
        }
        
        if isCollectingEmoji {
            result = result + Text(emojiBuffer)
        }
        
        if !currentText.isEmpty {
            result = result + Text(currentText)
        }
        
        return result
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

import SwiftUI

/// 共享的评论输入组件
struct CommentInputView: View {
    @Binding var text: String
    var replyToUserName: String?
    var isSubmitting: Bool
    var canSubmit: Bool
    var maxCommentLength: Int = 140

    var onCancelReply: () -> Void
    var onSubmit: () -> Void

    @FocusState private var isInputFocused: Bool
    @State private var showStampPicker = false

    private let emojiKeys: [String] = Array(EmojiHelper.emojisMap.keys).sorted()

    var body: some View {
        VStack(spacing: 0) {
            // 回复提示栏 (整合进卡片)
            if let replyUserName = replyToUserName {
                HStack {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("回复 \(replyUserName)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Spacer()
                    Button(action: onCancelReply) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)
            }

            // 主输入区域
            VStack(spacing: 8) {
                HStack(alignment: .bottom, spacing: 10) {
                    // 独立的圆角输入框
                    HStack(alignment: .bottom) {
                        TextField(replyToUserName == nil ? "说点什么..." : "回复 \(replyToUserName ?? "")...", text: $text, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(1...5)
                            .focused($isInputFocused)
                            .disabled(isSubmitting)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)

                        if !text.isEmpty {
                            Text("\(text.count)/\(maxCommentLength)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(text.count > maxCommentLength ? .red : .secondary)
                                .padding(.trailing, 8)
                                .padding(.bottom, 8)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(uiColor: .secondarySystemFill))
                    )

                    // 按钮组
                    HStack(spacing: 12) {
                        Button(action: toggleStampPicker) {
                            Image(systemName: showStampPicker ? "keyboard" : "face.smiling")
                                .font(.system(size: 22))
                                .foregroundColor(showStampPicker ? .blue : .secondary)
                        }

                        Button(action: {
                            onSubmit()
                            isInputFocused = false
                        }) {
                            if isSubmitting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(canSubmit ? .blue : .gray.opacity(0.5))
                            }
                        }
                        .disabled(!canSubmit || isSubmitting)
                    }
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, 12)
                .padding(.top, replyToUserName == nil ? 10 : 0)
                .padding(.bottom, 10)

                // 表情面板
                if showStampPicker {
                    stampPickerSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showStampPicker)
        .animation(.easeOut(duration: 0.2), value: replyToUserName)
    }

    private var stampPickerSection: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 45))], spacing: 12) {
                    ForEach(emojiKeys, id: \.self) { key in
                        Button(action: {
                            text += key
                        }) {
                            stampImage(for: key)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 220) // 大约 3-4 行的高度
        }
    }

    @ViewBuilder
    private func stampImage(for key: String) -> some View {
        if let imageName = EmojiHelper.getEmojiImageName(for: key) {
            if let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(key).font(.caption2)
            }
        } else {
            Text(key).font(.caption2)
        }
    }

    private func toggleStampPicker() {
        if showStampPicker {
            isInputFocused = true
            showStampPicker = false
        } else {
            isInputFocused = false
            showStampPicker = true
        }
    }
}

#Preview {
    VStack {
        Spacer()
        CommentInputView(
            text: .constant("Hello world"),
            replyToUserName: "OpenCode",
            isSubmitting: false,
            canSubmit: true,
            onCancelReply: {},
            onSubmit: {}
        )
    }
}

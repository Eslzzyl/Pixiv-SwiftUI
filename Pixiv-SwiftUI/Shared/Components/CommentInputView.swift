import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

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

    @Namespace private var glassNamespace

    var body: some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            glassInputView
        } else {
            legacyInputView
        }
        #else
        legacyInputView
        #endif
    }

    #if os(iOS)
    @available(iOS 26.0, *)
    private var glassInputView: some View {
        GlassEffectContainer {
            // 主输入区域与独立关闭按钮的 HStack
            HStack(alignment: .bottom, spacing: 10) {
                // 1. 主输入 Blob
                VStack(spacing: 0) {
                    // 回复提示栏 (集成在主 Blob 内)
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
                        .glassEffectID("replyBar", in: glassNamespace)
                    }

                    VStack(spacing: 0) {
                        HStack(alignment: .bottom, spacing: 10) {
                            TextField(replyToUserName == nil ? "说点什么..." : "回复 \(replyToUserName ?? "")...", text: $text, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(1...5)
                                .focused($isInputFocused)
                                .disabled(isSubmitting)
                                .submitLabel(.send)
                                .onSubmit {
                                    if canSubmit {
                                        onSubmit()
                                        isInputFocused = false
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .glassEffectID("inputField", in: glassNamespace)

                            // 功能按钮 (表情 & 发送)
                            if isInputFocused || showStampPicker || !text.isEmpty {
                                HStack(spacing: 12) {
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        toggleStampPicker()
                                    }) {
                                        Image(systemName: showStampPicker ? "keyboard" : "face.smiling")
                                            .font(.system(size: 20))
                                            .foregroundColor(showStampPicker ? .blue : .secondary)
                                    }
                                    .frame(width: 44, height: 44)
                                    .glassEffectID("emojiBtn", in: glassNamespace)

                                    if !text.isEmpty {
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            onSubmit()
                                            isInputFocused = false
                                            showStampPicker = false
                                        }) {
                                            if isSubmitting {
                                                ProgressView().controlSize(.small)
                                            } else {
                                                Image(systemName: "paperplane.fill")
                                                    .font(.system(size: 19))
                                                    .foregroundColor(canSubmit ? .blue : .gray.opacity(0.5))
                                            }
                                        }
                                        .frame(width: 44, height: 44)
                                        .disabled(!canSubmit || isSubmitting)
                                        .glassEffectID("sendBtn", in: glassNamespace)
                                    }
                                }
                                .padding(.trailing, 8)
                            }
                        }

                        // 字符数提示
                        if text.count > Int(Double(maxCommentLength) * 0.8) {
                            HStack {
                                Spacer()
                                Text("\(text.count)/\(maxCommentLength)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(text.count > maxCommentLength ? .red : .secondary.opacity(0.8))
                                    .padding(.trailing, 24)
                                    .padding(.bottom, 4)
                            }
                            .transition(.opacity)
                        }

                        // 表情面板
                        if showStampPicker {
                            stampPickerSection
                                .glassEffectID("stampPicker", in: glassNamespace)
                        }
                    }
                }
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                .glassEffectID("inputBlob", in: glassNamespace)

                // 2. 独立的圆形关闭按钮 Blob
                if isInputFocused || showStampPicker {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        isInputFocused = false
                        showStampPicker = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular, in: Circle())
                    .glassEffectID("closeButton", in: glassNamespace)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
    #endif

    private var legacyInputView: some View {
        VStack(spacing: 0) {
            if let replyUserName = replyToUserName {
                HStack {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("回复 \(replyUserName)").font(.caption2).foregroundColor(.blue)
                    Spacer()
                    Button(action: onCancelReply) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            legacyInputField
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            HStack {
                if !text.isEmpty {
                    Text("\(text.count)/\(maxCommentLength)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(text.count > maxCommentLength ? .red : .secondary)
                }
                Spacer()
                legacyActionButtons
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            #if os(iOS)
            if showStampPicker { stampPickerSection }
            #endif
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var legacyInputField: some View {
        TextField(replyToUserName == nil ? "说点什么..." : "回复 \(replyToUserName ?? "")...", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1...10)
            .focused($isInputFocused)
            .disabled(isSubmitting)
            .submitLabel(.send)
            .onSubmit {
                #if os(iOS)
                if canSubmit {
                    onSubmit()
                    isInputFocused = false
                }
                #endif
            }
            .padding(.vertical, 8)
    }

    private var legacyActionButtons: some View {
        HStack(spacing: 12) {
            Button(action: toggleStampPicker) {
                Image(systemName: showStampPicker ? "keyboard" : "face.smiling")
                    .font(.system(size: 20))
                    .foregroundColor(showStampPicker ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            #if os(macOS)
            .popover(isPresented: $showStampPicker) {
                stampPickerSection
                    .frame(width: 300)
                    .fixedSize(horizontal: false, vertical: true)
            }
            #endif

            #if os(iOS)
            if isInputFocused || showStampPicker {
                Button(action: {
                    isInputFocused = false
                    showStampPicker = false
                }) {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            } else if !text.isEmpty {
                sendButton
            }
            #else
            if !text.isEmpty {
                sendButton
            }
            #endif
        }
        .transition(.opacity)
    }

    private var sendButton: some View {
        Button(action: {
            onSubmit()
            #if os(iOS)
            isInputFocused = false
            #endif
        }) {
            if isSubmitting {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(canSubmit ? .blue : .gray.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit || isSubmitting)
    }

    private var stampPickerSection: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 45))], spacing: 12) {
                    ForEach(emojiKeys, id: \.self) { key in
                        Button(action: {
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
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
            .frame(maxHeight: 220)
        }
    }

    @ViewBuilder
    private func stampImage(for key: String) -> some View {
        if let imageName = EmojiHelper.getEmojiImageName(for: key) {
            #if os(iOS)
            if let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(key).font(.caption2)
            }
            #else
            if let nsImage = NSImage(named: imageName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(key).font(.caption2)
            }
            #endif
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

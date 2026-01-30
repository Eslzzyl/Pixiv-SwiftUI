import SwiftUI

struct StampPickerView: View {
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 50, maximum: 60), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(emojiKeys, id: \.self) { key in
                        stampButton(for: key)
                    }
                }
                .padding()
            }
            .navigationTitle("选择表情")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }

    private var emojiKeys: [String] {
        Array(EmojiHelper.emojisMap.keys).sorted()
    }

    private func stampButton(for key: String) -> some View {
        Button(action: {
            onSelect(key)
            dismiss()
        }) {
            stampImage(for: key)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func stampImage(for key: String) -> some View {
        if let imageName = EmojiHelper.getEmojiImageName(for: key) {
            #if canImport(UIKit)
            if let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(key)
            }
            #else
            if let nsImage = NSImage(named: imageName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(key)
            }
            #endif
        } else {
            Text(key)
        }
    }
}

#Preview {
    StampPickerView { stamp in
        print("Selected: \(stamp)")
    }
}


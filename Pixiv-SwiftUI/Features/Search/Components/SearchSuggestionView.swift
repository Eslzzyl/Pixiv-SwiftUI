import SwiftUI

/// 搜索建议视图，用于在搜索栏中显示提示、快捷跳转等
struct SearchSuggestionView: View {
    @ObservedObject var store: SearchStore
    var accountStore: AccountStore
    @Binding var pendingIllustId: Int?
    @Binding var pendingUserId: String?
    var triggerHaptic: () -> Void
    var copyToClipboard: (String) -> Void
    var addBlockedTag: (String, String?) -> Void
    var onSearch: ((String) -> Void)? // 可选的立即搜索回调

    var body: some View {
        Group {
            // ID 快捷跳转部分
            if let number = extractedNumber, accountStore.isLoggedIn {
                Section("ID 快捷跳转") {
                    // 跳转至插画详情
                    Button {
                        triggerHaptic()
                        pendingIllustId = number
                        // 跳转 ID 时不需要保持搜索建议，清空搜索词
                        store.searchText = ""
                    } label: {
                        Label {
                            HStack {
                                Text("查看插画")
                                Spacer()
                                Text(String(number))
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "photo")
                        }
                    }

                    // 跳转至用户详情
                    Button {
                        triggerHaptic()
                        pendingUserId = String(number)
                        // 跳转 ID 时不需要保持搜索建议，清空搜索词
                        store.searchText = ""
                    } label: {
                        Label {
                            HStack {
                                Text("查看作者")
                                Spacer()
                                Text(String(number))
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "person")
                        }
                    }
                }
            }

            // 标签建议部分
            Section("标签建议") {
                ForEach(store.suggestions) { tag in
                    Button {
                        let words = store.searchText.split(separator: " ")
                        var newText = ""
                        // 处理多选标签补全
                        if words.count > 1 {
                            newText = String(words.dropLast().joined(separator: " ") + " ")
                        }
                        newText += tag.name + " "
                        let completedText = newText.trimmingCharacters(in: .whitespaces)
                        store.searchText = completedText
                        
                        // 如果提供了搜索回调，则立即执行搜索并添加到历史记录
                        if let onSearch = onSearch {
                            onSearch(completedText)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tag.name)
                                    .foregroundColor(.primary)
                                if let translated = tag.translatedName {
                                    Text(translated)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            #if os(macOS)
                            // macOS 特有的补全图标
                            Image(systemName: "arrow.up.left")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            #endif
                        }
                    }
                    .contextMenu {
                        Button {
                            copyToClipboard(tag.name)
                        } label: {
                            Label("复制 tag", systemImage: "doc.on.doc")
                        }

                        if accountStore.isLoggedIn {
                            Button {
                                triggerHaptic()
                                addBlockedTag(tag.name, tag.translatedName)
                            } label: {
                                Label("屏蔽 tag", systemImage: "eye.slash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var extractedNumber: Int? {
        let pattern = #"\b(\d+)\b"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: store.searchText, range: NSRange(store.searchText.startIndex..., in: store.searchText)),
           let range = Range(match.range(at: 1), in: store.searchText) {
            return Int(store.searchText[range])
        }
        return nil
    }
}

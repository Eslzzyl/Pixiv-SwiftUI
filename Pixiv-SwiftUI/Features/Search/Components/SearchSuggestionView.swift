import SwiftUI

/// 搜索建议视图，用于在搜索栏中显示提示、快捷跳转等
struct SearchSuggestionView: View {
    var store: SearchStore
    var accountStore: AccountStore
    @Binding var pendingIllustId: Int?
    @Binding var pendingUserId: String?
    var triggerHaptic: () -> Void
    var copyToClipboard: (String) -> Void
    var addBlockedTag: (String, String?) -> Void

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
            if !store.suggestions.isEmpty {
                Section("标签建议") {
                    ForEach(store.suggestions) { tag in
                        Button {
                            store.searchText = completedSearchText(with: tag.tagName)
                        } label: {
                        HStack {
                            Image(systemName: tag.isLocalMatch ? "checkmark.circle" : "magnifyingglass")
                                .foregroundColor(tag.isLocalMatch ? .accentColor : .secondary)
                                .font(.system(size: 14))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tag.tagName)
                                    .foregroundColor(.primary)
                                if let translated = tag.displayTranslation {
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
                            copyToClipboard(tag.tagName)
                        } label: {
                            Label("复制 tag", systemImage: "doc.on.doc")
                        }

                        if accountStore.isLoggedIn {
                            Button {
                                triggerHaptic()
                                addBlockedTag(tag.tagName, tag.displayTranslation)
                            } label: {
                                Label("屏蔽 tag", systemImage: "eye.slash")
                            }
                        }
                    }
                }
            }
        }

        // 增加底部留白，防止 iOS 键盘及输入框遮挡
            #if os(iOS)
            if !store.suggestions.isEmpty || extractedNumber != nil {
                Section {
                    Color.clear
                        .frame(height: 60)
                        .listRowBackground(Color.clear)
                }
            }
            #endif
        }
    }

    private func completedSearchText(with tagName: String) -> String {
        let hasTrailingWhitespace = store.searchText.unicodeScalars.last.map {
            CharacterSet.whitespacesAndNewlines.contains($0)
        } ?? false

        let tokens = store.searchText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var completedTokens = tokens
        if hasTrailingWhitespace || completedTokens.isEmpty {
            completedTokens.append(tagName)
        } else {
            completedTokens[completedTokens.count - 1] = tagName
        }
        return completedTokens.joined(separator: " ") + " "
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

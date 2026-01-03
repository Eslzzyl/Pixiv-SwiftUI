import SwiftUI

struct SearchView: View {
    @StateObject private var store = SearchStore()
    @State private var navigateToResult = false
    @State private var selectedTag: String = ""
    @State private var showClearHistoryConfirmation = false
    @State private var showBlockToast = false
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var path = NavigationPath()

    private var columnCount: Int {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad ? userSettingStore.userSetting.hCrossCount : userSettingStore.userSetting.crossCount
        #else
        userSettingStore.userSetting.hCrossCount
        #endif
    }

    private var trendTagColumns: [[TrendTag]] {
        var result = Array(repeating: [TrendTag](), count: columnCount)
        for (index, item) in store.trendTags.enumerated() {
            result[index % columnCount].append(item)
        }
        return result
    }
    
    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #else
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(text, forType: .string)
        #endif
    }
    
    private func triggerHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                if store.searchText.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading) {
                            if !store.searchHistory.isEmpty {
                                Text("搜索历史")
                                    .font(.headline)
                                    .padding(.horizontal)
                                    .padding(.top)

                                FlowLayout(spacing: 8) {
                                    ForEach(store.searchHistory) { tag in
                                        Button(action: {
                                            store.searchText = tag.name
                                            selectedTag = tag.name
                                            navigateToResult = true
                                        }) {
                                            TagChip(searchTag: tag)
                                        }
                                        .contextMenu {
                                            Button(action: {
                                                copyToClipboard(tag.name)
                                            }) {
                                                Label("复制 tag", systemImage: "doc.on.doc")
                                            }
                                            
                                            Button(action: {
                                                triggerHaptic()
                                                try? userSettingStore.addBlockedTagWithInfo(tag.name, translatedName: tag.translatedName)
                                                showBlockToast = true
                                            }) {
                                                Label("屏蔽 tag", systemImage: "eye.slash")
                                            }
                                            
                                            Button(role: .destructive, action: {
                                                store.removeHistory(tag.name)
                                            }) {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            Text("热门标签")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top)

                            HStack(alignment: .top, spacing: 10) {
                                ForEach(0..<columnCount, id: \.self) { columnIndex in
                                    LazyVStack(spacing: 10) {
                                        ForEach(trendTagColumns[columnIndex]) { tag in
                                            Button(action: {
                                                let searchTag = SearchTag(name: tag.tag, translatedName: tag.translatedName)
                                                store.addHistory(searchTag)
                                                store.searchText = tag.tag
                                                selectedTag = tag.tag
                                                navigateToResult = true
                                            }) {
                                                ZStack(alignment: .bottomLeading) {
                                                    CachedAsyncImage(
                                                        urlString: tag.illust.imageUrls.medium,
                                                        aspectRatio: tag.illust.aspectRatio
                                                    )
                                                    .clipped()

                                                    LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.7)]), startPoint: .top, endPoint: .bottom)

                                                    VStack(alignment: .leading) {
                                                        Text(tag.tag)
                                                            .font(.subheadline)
                                                            .bold()
                                                            .foregroundColor(.white)
                                                            .lineLimit(1)
                                                        if let translated = tag.translatedName {
                                                            Text(translated)
                                                                .font(.caption)
                                                                .foregroundColor(.white.opacity(0.8))
                                                                .lineLimit(1)
                                                        }
                                                    }
                                                    .padding(8)
                                                }
                                                .cornerRadius(16)
                                            }
                                            .contextMenu {
                                                Button(action: {
                                                    copyToClipboard(tag.tag)
                                                }) {
                                                    Label("复制 tag", systemImage: "doc.on.doc")
                                                }

                                                Button(action: {
                                                    triggerHaptic()
                                                    try? userSettingStore.addBlockedTagWithInfo(tag.tag, translatedName: tag.translatedName)
                                                    showBlockToast = true
                                                }) {
                                                    Label("屏蔽 tag", systemImage: "eye.slash")
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    List(store.suggestions) { tag in
                        Button(action: {
                            let words = store.searchText.split(separator: " ")
                            var newText = ""
                            if words.count > 1 {
                                newText = String(words.dropLast().joined(separator: " ") + " ")
                            }
                            newText += tag.name + " "
                            store.searchText = newText.trimmingCharacters(in: .whitespaces)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tag.name)
                                    .foregroundColor(.primary)
                                if let translated = tag.translatedName {
                                    Text(translated)
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .contextMenu {
                            Button(action: {
                                copyToClipboard(tag.name)
                            }) {
                                Label("复制 tag", systemImage: "doc.on.doc")
                            }
                            
                            Button(action: {
                                triggerHaptic()
                                try? userSettingStore.addBlockedTagWithInfo(tag.name, translatedName: tag.translatedName)
                                showBlockToast = true
                            }) {
                                Label("屏蔽 tag", systemImage: "eye.slash")
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("搜索")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if !store.searchHistory.isEmpty {
                        Button(action: {
                            showClearHistoryConfirmation = true
                        }) {
                            Image(systemName: "trash")
                        }
                        .confirmationDialog("确定要清除所有搜索历史吗？", isPresented: $showClearHistoryConfirmation, titleVisibility: .visible) {
                            Button("清除所有", role: .destructive) {
                                triggerHaptic()
                                store.clearHistory()
                            }
                            Button("取消", role: .cancel) {}
                        }
                    }
                }
            }
            .onAppear {
                store.loadSearchHistory()
            }
            #if os(iOS)
            .searchable(text: $store.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索插画、用户")
            #else
            .searchable(text: $store.searchText, prompt: "搜索插画、用户")
            #endif
            .onSubmit(of: .search) {
                if !store.searchText.isEmpty {
                    selectedTag = store.searchText
                    navigateToResult = true
                }
            }
            .task {
                await store.fetchTrendTags()
            }
            .navigationDestination(isPresented: $navigateToResult) {
                SearchResultView(word: selectedTag, store: store)
            }
            .navigationDestination(for: Illusts.self) { illust in
                IllustDetailView(illust: illust)
            }
            .navigationDestination(for: User.self) { user in
                UserDetailView(userId: user.id.stringValue)
            }
            .onChange(of: navigateToResult) { _, newValue in
                if !newValue {
                    store.searchText = selectedTag
                }
            }
            .toast(isPresented: $showBlockToast, message: "已屏蔽 Tag")
        }
    }
}

#Preview {
    SearchView()
}

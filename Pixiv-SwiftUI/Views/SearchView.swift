import SwiftUI

struct SearchView: View {
    @StateObject private var store = SearchStore()
    @State private var navigateToResult = false
    @State private var selectedTag: String = ""
    @State private var showClearHistoryConfirmation = false
    @State private var showBlockToast = false
    @Environment(UserSettingStore.self) var userSettingStore
    
    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #else
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(text, forType: .string)
        #endif
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if store.searchText.isEmpty {
                    // 搜索历史和热门标签
                    ScrollView {
                        VStack(alignment: .leading) {
                            if !store.searchHistory.isEmpty {
                                HStack {
                                    Text("搜索历史")
                                        .font(.headline)
                                    Spacer()
                                    Button(action: {
                                        showClearHistoryConfirmation = true
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.title3)
                                            .foregroundColor(.secondary)
                                    }
                                    .confirmationDialog("确定要清除所有搜索历史吗？", isPresented: $showClearHistoryConfirmation, titleVisibility: .visible) {
                                        Button("清除所有", role: .destructive) {
                                            store.clearHistory()
                                        }
                                        Button("取消", role: .cancel) {}
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(store.searchHistory) { tag in
                                        Button(action: {
                                            store.addHistory(tag)
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
                                                try? userSettingStore.addBlockedTag(tag.name)
                                                showBlockToast = true
                                            }) {
                                                Label("屏蔽 tag", systemImage: "eye.slash")
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
                            
                            // 热门标签列表 (带图片)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                                ForEach(store.trendTags) { tag in
                                    Button(action: {
                                        let searchTag = SearchTag(name: tag.tag, translatedName: tag.translatedName)
                                        store.addHistory(searchTag)
                                        store.searchText = tag.tag
                                        selectedTag = tag.tag
                                        navigateToResult = true
                                    }) {
                                        ZStack(alignment: .bottomLeading) {
                                            CachedAsyncImage(urlString: tag.illust.imageUrls.medium)
                                                .frame(height: 100)
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
                                            try? userSettingStore.addBlockedTag(tag.tag)
                                            showBlockToast = true
                                        }) {
                                            Label("屏蔽 tag", systemImage: "eye.slash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    // 搜索建议
                    List(store.suggestions) { tag in
                        Button(action: {
                            store.addHistory(tag)
                            store.searchText = tag.name
                            selectedTag = tag.name
                            navigateToResult = true
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
                                try? userSettingStore.addBlockedTag(tag.name)
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
            .onChange(of: navigateToResult) { _, newValue in
                // 当从搜索结果页返回（navigateToResult 从 true 变为 false）时，清空搜索框
                if !newValue {
                    store.searchText = ""
                }
            }
            .toast(isPresented: $showBlockToast, message: "已屏蔽 Tag")
        }
    }
}

#Preview {
    SearchView()
}

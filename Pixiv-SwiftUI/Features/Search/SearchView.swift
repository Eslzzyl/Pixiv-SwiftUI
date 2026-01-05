import SwiftUI

struct SearchView: View {
    @StateObject private var store = SearchStore()
    @State private var navigateToResult = false
    @State private var selectedTag: String = ""
    @State private var showClearHistoryConfirmation = false
    @State private var showBlockToast = false
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var path = NavigationPath()

    @State private var pendingIllustId: Int?
    @State private var pendingUserId: String?
    @State private var isLoadingDetail = false
    @State private var show404Error = false
    @State private var errorMessage = ""
    @State private var showProfilePanel = false
    var accountStore: AccountStore = AccountStore.shared

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

    private var extractedNumber: Int? {
        let pattern = #"\b(\d+)\b"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: store.searchText, range: NSRange(store.searchText.startIndex..., in: store.searchText)),
           let range = Range(match.range(at: 1), in: store.searchText) {
            return Int(store.searchText[range])
        }
        return nil
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
                    searchHistoryAndTrends
                } else {
                    suggestionList
                }
            }
            .navigationTitle("搜索")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        if !store.searchHistory.isEmpty && store.searchText.isEmpty {
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
                        ProfileButton(accountStore: accountStore, isPresented: $showProfilePanel)
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
            .navigationDestination(for: UserDetailUser.self) { userDetailUser in
                UserDetailView(userId: String(userDetailUser.id))
            }
            .onChange(of: navigateToResult) { _, newValue in
                if !newValue {
                    store.searchText = selectedTag
                }
            }
            .task(id: pendingIllustId) {
                if let illustId = pendingIllustId {
                    isLoadingDetail = true
                    defer { pendingIllustId = nil }
                    do {
                        let illust = try await PixivAPI.shared.getIllustDetail(illustId: illustId)
                        await MainActor.run {
                            path.append(illust)
                        }
                    } catch let error as NetworkError {
                        if case .httpError(404) = error {
                            errorMessage = "未找到插画 (ID: \(illustId))"
                            show404Error = true
                        }
                    } catch {
                        print("Failed to load illust: \(error)")
                    }
                    isLoadingDetail = false
                }
            }
            .task(id: pendingUserId) {
                if let userId = pendingUserId {
                    isLoadingDetail = true
                    defer { pendingUserId = nil }
                    do {
                        let userDetail = try await PixivAPI.shared.getUserDetail(userId: userId)
                        await MainActor.run {
                            path.append(userDetail.user)
                        }
                    } catch let error as NetworkError {
                        if case .httpError(404) = error {
                            errorMessage = "未找到用户 (ID: \(userId))"
                            show404Error = true
                        }
                    } catch {
                        print("Failed to load user: \(error)")
                    }
                    isLoadingDetail = false
                }
            }
            .overlay {
                if isLoadingDetail {
                    ZStack {
                        Color.black.opacity(0.3)
                        ProgressView()
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                    }
                    .ignoresSafeArea()
                }
            }
            .toast(isPresented: $showBlockToast, message: "已屏蔽 Tag")
            .toast(isPresented: $show404Error, message: errorMessage)
            .sheet(isPresented: $showProfilePanel) {
                ProfilePanelView(accountStore: accountStore, isPresented: $showProfilePanel)
            }
            .onChange(of: accountStore.navigationRequest) { _, newValue in
                if let request = newValue {
                    switch request {
                    case .userDetail(let userId):
                        path.append(User(id: .string(userId), name: "", account: ""))
                    case .illustDetail(let illust):
                        path.append(illust)
                    }
                    accountStore.navigationRequest = nil
                }
            }
        }
    }

    private var searchHistoryAndTrends: some View {
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
    }

    private var suggestionList: some View {
        List {
            if let number = extractedNumber {
                Section("ID 快捷跳转") {
                    Button(action: {
                        triggerHaptic()
                        pendingIllustId = number
                    }) {
                        HStack {
                            Text("查看插画")
                            Spacer()
                            Text(String(number))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(action: {
                        triggerHaptic()
                        pendingUserId = String(number)
                    }) {
                        HStack {
                            Text("查看作者")
                            Spacer()
                            Text(String(number))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("标签建议") {
                ForEach(store.suggestions) { tag in
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
            }
        }
        .listStyle(.sidebar)
    }
}

#Preview {
    SearchView()
}

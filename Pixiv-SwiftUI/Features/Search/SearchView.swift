import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#endif

struct SearchView: View {
    @State private var store = SearchStore.shared
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
    @State private var showSauceToast = false
    @State private var sauceToastMessage = ""
    @State private var showImageFileImporter = false
    @State private var isSearchPresented = false
    @State private var isHistoryExpanded = false
    #if os(iOS)
    @State private var showPhotosPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    #endif
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

    private var recommendedSearchTagColumns: [[TrendTag]] {
        var result = Array(repeating: [TrendTag](), count: columnCount)
        for (index, item) in store.recommendedSearchTags.enumerated() {
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

    private func startSauceNaoSearch() {
        guard accountStore.isLoggedIn else {
            showSauceToastMessage(String(localized: "请先登录"))
            return
        }
        #if os(iOS)
        showPhotosPicker = true
        #else
        showImageFileImporter = true
        #endif
    }

    private func showSauceToastMessage(_ message: String) {
        sauceToastMessage = message
        showSauceToast = true
    }

    private func handleImportedImage(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await searchWithImageURL(url)
            }
        case .failure(let error):
            showSauceToastMessage("读取图片失败: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func searchWithImageURL(_ url: URL) async {
        do {
            let data = try loadImageData(from: url)
            let fileName = url.lastPathComponent.isEmpty ? "image.jpg" : url.lastPathComponent
            await searchWithImageData(data, fileName: fileName)
        } catch {
            showSauceToastMessage("读取图片失败: \(error.localizedDescription)")
        }
    }

    private func loadImageData(from url: URL) throws -> Data {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }

    @MainActor
    private func searchWithImageData(_ data: Data, fileName: String) async {
        let requestId = SauceNaoSearchRequestStore.shared.enqueue(imageData: data, fileName: fileName)
        path.append(SauceNaoResultTarget(requestId: requestId))
    }

    #if os(iOS)
    private func handleSelectedPhotoItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                guard let imageData = try await item.loadTransferable(type: Data.self) else {
                    await MainActor.run {
                        showSauceToastMessage(String(localized: "读取图片失败"))
                    }
                    return
                }
                await searchWithImageData(imageData, fileName: "photo.jpg")
                await MainActor.run {
                    selectedPhotoItem = nil
                }
            } catch {
                await MainActor.run {
                    showSauceToastMessage("读取图片失败: \(error.localizedDescription)")
                    selectedPhotoItem = nil
                }
            }
        }
    }
    #endif

    private var searchPrompt: String {
        accountStore.isLoggedIn ? String(localized: "搜索插画、小说和画师") : String(localized: "请先登录以使用搜索")
    }

    private func normalizedSearchQuery(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    @MainActor
    private func performSearch(word: String, translatedName: String? = nil) {
        let normalizedWord = normalizedSearchQuery(word)
        guard !normalizedWord.isEmpty else { return }

        isSearchPresented = false
        store.addHistory(SearchTag(name: normalizedWord, translatedName: translatedName))
        store.searchText = normalizedWord
        selectedTag = normalizedWord

        let preloadToken = UUID()
        SearchResultStore.scheduleSearchEntryPseudoPopularPreload(
            word: normalizedWord,
            token: preloadToken,
            isPremium: accountStore.currentAccount?.isPremium == 1,
            defaultSort: SearchSortOption(rawValue: userSettingStore.userSetting.defaultSearchSort) ?? .dateDesc
        )

        path = NavigationPath()
        path.append(SearchResultTarget(word: normalizedWord, preloadToken: preloadToken))
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                #if os(iOS)
                if store.searchText.isEmpty {
                    searchHistoryAndTrends
                } else {
                    suggestionList
                }
                #else
                searchHistoryAndTrends
                #endif
            }
            #if os(iOS)
            .searchable(
                text: $store.searchText,
                isPresented: $isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: searchPrompt
            )
            .searchSuggestions {
                SearchSuggestionView(
                    store: store,
                    accountStore: accountStore,
                    pendingIllustId: $pendingIllustId,
                    pendingUserId: $pendingUserId,
                    triggerHaptic: triggerHaptic,
                    copyToClipboard: copyToClipboard,
                    addBlockedTag: { name, translatedName in
                        try? userSettingStore.addBlockedTagWithInfo(name, translatedName: translatedName)
                        showBlockToast = true
                    }
                )
            }
            #else
            .searchable(
                text: $store.searchText,
                prompt: searchPrompt
            ) {
                SearchSuggestionView(
                    store: store,
                    accountStore: accountStore,
                    pendingIllustId: $pendingIllustId,
                    pendingUserId: $pendingUserId,
                    triggerHaptic: triggerHaptic,
                    copyToClipboard: copyToClipboard,
                    addBlockedTag: { name, translatedName in
                        try? userSettingStore.addBlockedTagWithInfo(name, translatedName: translatedName)
                        showBlockToast = true
                    }
                )
            }
            #endif
            .navigationTitle(String(localized: "搜索"))
            .toolbar {
                if accountStore.isLoggedIn {
                    ToolbarItem {
                        Button(action: {
                            startSauceNaoSearch()
                        }) {
                            Image(systemName: "photo.badge.magnifyingglass")
                        }
                    }
                }
                #if os(iOS)
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed)
                }
                ToolbarItem {
                    ProfileButton(accountStore: accountStore, isPresented: $showProfilePanel)
                }
                #endif
            }
            .onAppear {
                store.loadSearchHistory()
                if !store.searchText.isEmpty {
                    isSearchPresented = true
                }
            }
            .onSubmit(of: .search) {
                guard accountStore.isLoggedIn else { return }
                if !store.searchText.isEmpty {
                    performSearch(word: store.searchText)
                }
            }
            .task {
                await store.fetchTrendTags()
            }
            .task(id: accountStore.isWebLoggedIn) {
                guard accountStore.isWebLoggedIn else { return }
                await store.fetchRecommendedTags()
            }
            .pixivNavigationDestinations()
            .navigationDestination(for: SauceNaoResultTarget.self) { target in
                SauceNaoResultListView(requestId: target.requestId)
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
                            errorMessage = String(localized: "没有找到插画") + " (ID: \(illustId))"
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
                            errorMessage = String(localized: "没有找到画师") + " (ID: \(userId))"
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
            .toast(isPresented: $showBlockToast, message: String(localized: "已屏蔽 Tag"))
            .toast(isPresented: $show404Error, message: errorMessage)
            .toast(isPresented: $showSauceToast, message: sauceToastMessage)
            .sheet(isPresented: $showProfilePanel) {
                #if os(iOS)
                ProfilePanelView(accountStore: accountStore, isPresented: $showProfilePanel)
                #endif
            }
            .fileImporter(
                isPresented: $showImageFileImporter,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false,
                onCompletion: handleImportedImage
            )
            #if os(iOS)
            .photosPicker(
                isPresented: $showPhotosPicker,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) { _, newItem in
                handleSelectedPhotoItem(newItem)
            }
            #endif
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

    private func trendTagContent(_ tag: TrendTag) -> some View {
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
                    .minimumScaleFactor(0.8)
                if let translated = TagTranslationService.shared.getDisplayTranslation(for: tag.tag, officialTranslation: tag.translatedName), !translated.isEmpty {
                    Text(translated)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cornerRadius(16)
        .contentShape(Rectangle())
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var searchHistoryAndTrends: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if !store.searchHistory.isEmpty {
                    HStack(spacing: 12) {
                        Text("搜索历史")
                            .font(.headline)

                        Spacer()

                        if accountStore.isLoggedIn {
                            Button(action: {
                                showClearHistoryConfirmation = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("清空")
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    FlowLayout(spacing: 6) {
                        let historyToDisplay = isHistoryExpanded ? store.searchHistory : Array(store.searchHistory.prefix(10))
                        ForEach(historyToDisplay) { tag in
                            Group {
                                if accountStore.isLoggedIn {
                                    Button(action: {
                                        performSearch(word: tag.name, translatedName: tag.translatedName)
                                    }) {
                                        TagChip(searchTag: tag)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    TagChip(searchTag: tag)
                                }
                            }
                            .contextMenu {
                                Button(action: {
                                    copyToClipboard(tag.name)
                                }) {
                                    Label(String(localized: "复制 tag"), systemImage: "doc.on.doc")
                                }

                                if accountStore.isLoggedIn {
                                    Button(action: {
                                        triggerHaptic()
                                        try? userSettingStore.addBlockedTagWithInfo(tag.name, translatedName: tag.translatedName)
                                        showBlockToast = true
                                    }) {
                                        Label(String(localized: "屏蔽 tag"), systemImage: "eye.slash")
                                    }

                                    Button(role: .destructive, action: {
                                        store.removeHistory(tag.name)
                                    }) {
                                        Label(String(localized: "删除"), systemImage: "trash")
                                    }
                                }
                            }
                        }

                        if store.searchHistory.count > 10 {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isHistoryExpanded.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text(isHistoryExpanded ? String(localized: "收起") : String(localized: "更多"))
                                    Image(systemName: isHistoryExpanded ? "chevron.up" : "chevron.down")
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                if accountStore.isWebLoggedIn {
                    if store.isLoadingRecommendedTags {
                        SkeletonRecommendedSearchTagsList()
                    } else if !store.recommendedSearchTags.isEmpty {
                        Text("推荐标签")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(store.recommendedSearchTags) { tag in
                                    Button(action: {
                                        performSearch(word: tag.tag, translatedName: tag.translatedName)
                                    }) {
                                        trendTagContent(tag)
                                            .frame(width: 140, height: 140)
                                            .contentShape(Rectangle())
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                SpotlightPreview()

                IllustRankingPreview()

                Text("热门标签")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)

                if store.isLoadingTrendTags && store.trendTags.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(0..<columnCount, id: \.self) { _ in
                            LazyVStack(spacing: 10) {
                                ForEach(0..<3, id: \.self) { _ in
                                    SkeletonTrendTag()
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                } else if !accountStore.isLoggedIn && store.trendTags.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("登录后查看热门标签")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .frame(height: 120)
                } else if !store.trendTags.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(0..<columnCount, id: \.self) { columnIndex in
                            LazyVStack(spacing: 10) {
                                ForEach(trendTagColumns[columnIndex]) { tag in
                                    Group {
                                        if accountStore.isLoggedIn {
                                            Button(action: {
                                                performSearch(word: tag.tag, translatedName: tag.translatedName)
                                            }) {
                                                trendTagContent(tag)
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            trendTagContent(tag)
                                        }
                                    }
                                    .contextMenu {
                                        Button(action: {
                                            copyToClipboard(tag.tag)
                                        }) {
                                            Label(String(localized: "复制 tag"), systemImage: "doc.on.doc")
                                        }

                                        if accountStore.isLoggedIn {
                                            Button(action: {
                                                triggerHaptic()
                                                try? userSettingStore.addBlockedTagWithInfo(tag.tag, translatedName: tag.translatedName)
                                                showBlockToast = true
                                            }) {
                                                Label(String(localized: "屏蔽 tag"), systemImage: "eye.slash")
                                            }
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
        .confirmationDialog(String(localized: "确定要清除所有搜索历史吗？"), isPresented: $showClearHistoryConfirmation, titleVisibility: .visible) {
            Button(String(localized: "清除所有"), role: .destructive) {
                triggerHaptic()
                store.clearHistory()
                isHistoryExpanded = false
            }
            Button(String(localized: "取消"), role: .cancel) {}
        }
    }

    private var suggestionList: some View {
        List {
            SearchSuggestionView(
                store: store,
                accountStore: accountStore,
                pendingIllustId: $pendingIllustId,
                pendingUserId: $pendingUserId,
                triggerHaptic: triggerHaptic,
                copyToClipboard: copyToClipboard,
                addBlockedTag: { name, translatedName in
                    try? userSettingStore.addBlockedTagWithInfo(name, translatedName: translatedName)
                    showBlockToast = true
                }
            )
        }
        .listStyle(.plain)
    }
}

#Preview {
    SearchView()
}

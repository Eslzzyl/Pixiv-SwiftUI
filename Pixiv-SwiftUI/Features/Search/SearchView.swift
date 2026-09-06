import SwiftUI
import UniformTypeIdentifiers
import os.log
#if os(iOS)
import PhotosUI
#endif

struct SearchView: View {
    @State private var store = SearchStore.shared
    @State private var vm = SearchViewModel()
    @State private var showClearHistoryConfirmation = false
    @State private var showBlockToast = false
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var path = NavigationPath()

    @State private var pendingIllustId: Int?
    @State private var pendingUserId: String?
    @State private var showProfilePanel = false
    @State private var isSearchPresented = false
    @State private var isHistoryExpanded = false
    var accountStore: AccountStore = .shared

    private var columnCount: Int {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad ? userSettingStore.userSetting.hCrossCount : userSettingStore.userSetting.crossCount
        #else
        userSettingStore.userSetting.hCrossCount
        #endif
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
        localSearchView
    }

    private var localSearchView: some View {
        #if os(iOS)
        @Bindable var store = store
        return navigationContent
            .searchable(
                text: $store.searchText,
                isPresented: $isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: vm.searchPrompt
            )
            .searchSuggestions {
                searchSuggestions
            }
            .onSubmit(of: .search, submitSearch)
        #else
        return navigationContent
        #endif
    }

    private var navigationContent: some View {
        #if os(macOS)
        @Bindable var bindableStore = store
        #endif

        return NavigationStack(path: $path) {
            VStack(spacing: 0) {
                #if os(iOS)
                if store.searchText.isEmpty || !isSearchPresented {
                    searchHistoryAndTrends
                } else {
                    suggestionList
                }
                #else
                searchHistoryAndTrends
                #endif
            }
            #if os(macOS)
            .searchable(
                text: $bindableStore.searchText,
                placement: .toolbar,
                prompt: vm.searchPrompt
            ) {
                searchSuggestions
            }
            .onSubmit(of: .search, submitSearch)
            #endif
            .navigationTitle(String(localized: "搜索"))
            .toolbar {
                if accountStore.isLoggedIn {
                    ToolbarItem {
                        Button(action: {
                            vm.startSauceNaoSearch()
                        }) {
                            Image(systemName: "photo.badge.magnifyingglass")
                        }
                        .accessibilityLabel(String(localized: "以图搜图"))
                    }
                }
                #if os(iOS)
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed)
                }
                ToolbarItem {
                    ProfileButton(accountStore: accountStore, isPresented: $showProfilePanel)
                }
                .hideSharedBackgroundIfAvailable()
                #endif
            }
            .onAppear {
                store.loadSearchHistory()
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
                    defer { pendingIllustId = nil }
                    await vm.loadIllustDetail(illustId: illustId, path: $path)
                }
            }
            .overlay {
                if vm.isLoadingDetail {
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
            .toast(isPresented: $vm.show404Error, message: vm.errorMessage)
            .toast(isPresented: $vm.showSauceToast, message: vm.sauceToastMessage)
            .sheet(isPresented: $showProfilePanel) {
                #if os(iOS)
                ProfilePanelView(accountStore: accountStore, isPresented: $showProfilePanel)
                #endif
            }
            .fileImporter(
                isPresented: $vm.showImageFileImporter,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false,
                onCompletion: vm.handleImportedImage
            )
            #if os(iOS)
            .photosPicker(
                isPresented: Binding(
                    get: { vm.selectedPhotoItem != nil || false },
                    set: { if !$0 { vm.selectedPhotoItem = nil } }
                ),
                selection: Binding(
                    get: { vm.selectedPhotoItem },
                    set: { vm.selectedPhotoItem = $0 }
                ),
                matching: .images
            )
            .onChange(of: vm.selectedPhotoItem) { _, newItem in
                vm.handleSelectedPhotoItem(newItem)
            }
            #endif
            .onChange(of: vm.pendingSauceNaoTarget) { _, target in
                if let target {
                    path.append(target)
                    vm.pendingSauceNaoTarget = nil
                }
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

    private var searchSuggestions: some View {
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

    private func submitSearch() {
        guard accountStore.isLoggedIn else { return }
        let submittedText = store.searchText
        guard !submittedText.isEmpty else { return }

        vm.performSearch(word: submittedText, path: $path)

        #if os(iOS)
        DispatchQueue.main.async {
            isSearchPresented = false
        }
        #endif
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
        #if os(macOS)
        MacOSStableScrollView {
            searchHistoryAndTrendsContent
        }
        #else
        ScrollView {
            searchHistoryAndTrendsContent
        }
        #endif
    }

    private var searchHistoryAndTrendsContent: some View {
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
                                .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .confirmationDialog(
                                String(localized: "确定要清除所有搜索历史吗？"),
                                isPresented: $showClearHistoryConfirmation,
                                titleVisibility: .visible
                            ) {
                                Button(String(localized: "清除所有"), role: .destructive) {
                                    triggerHaptic()
                                    store.clearHistory()
                                    isHistoryExpanded = false
                                }
                                Button(String(localized: "取消"), role: .cancel) {}
                            }
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
                                        vm.performSearch(word: tag.name, translatedName: tag.translatedName, path: $path)
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

                                if accountStore.isLoggedIn && vm.isSingleSearchTerm(tag.name) {
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
                    Group {
                        if store.isLoadingRecommendedTags {
                            SkeletonRecommendedSearchTagsList()
                                .transition(.opacity)
                        } else if !store.recommendedSearchTags.isEmpty {
                            VStack(alignment: .leading) {
                                Text("推荐标签")
                                    .font(.headline)
                                    .padding(.horizontal)
                                    .padding(.top)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(store.recommendedSearchTags) { tag in
                                            Button(action: {
                                                vm.performSearch(word: tag.tag, translatedName: tag.translatedName, path: $path)
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
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: store.isLoadingRecommendedTags)
                }

                SpotlightPreview()

                IllustRankingPreview()

                Text("热门标签")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)

                Group {
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
                        .transition(.opacity)
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
                                    ForEach(vm.trendTagColumns(columnCount: columnCount)[columnIndex]) { tag in
                                        Group {
                                            if accountStore.isLoggedIn {
                                                Button(action: {
                                                    vm.performSearch(word: tag.tag, translatedName: tag.translatedName, path: $path)
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
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: store.isLoadingTrendTags)
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

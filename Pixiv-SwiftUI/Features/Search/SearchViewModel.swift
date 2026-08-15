import Foundation
import SwiftUI
import os.log
#if os(iOS)
import PhotosUI
#endif

@MainActor
@Observable
final class SearchViewModel {
    var showSauceToast = false
    var sauceToastMessage = ""
    var isLoadingDetail = false
    var show404Error = false
    var errorMessage = ""
    var showImageFileImporter = false
    var pendingSauceNaoTarget: SauceNaoResultTarget?
    #if os(iOS)
    var selectedPhotoItem: PhotosPickerItem?
    #endif

    var showToast: ((String) -> Void)?

    @ObservationIgnored private let store: SearchStore
    @ObservationIgnored private let accountStore: AccountStore
    @ObservationIgnored private let userSettingStore: UserSettingStore

    init(
        store: SearchStore = .shared,
        accountStore: AccountStore = .shared,
        userSettingStore: UserSettingStore = .shared
    ) {
        self.store = store
        self.accountStore = accountStore
        self.userSettingStore = userSettingStore
    }

    // MARK: - Computed

    var searchPrompt: String {
        accountStore.isLoggedIn ? String(localized: "搜索插画、小说和画师") : String(localized: "请先登录以使用搜索")
    }

    func normalizedSearchQuery(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func isSingleSearchTerm(_ query: String) -> Bool {
        !query.contains(where: \.isWhitespace)
    }

    // MARK: - Masonry Layout

    func trendTagHeight(_ tag: TrendTag) -> CGFloat {
        guard let ratio = tag.illust.aspectRatio, ratio > 0 else { return 1.0 }
        return 1.0 / ratio
    }

    func trendTagColumns(columnCount: Int) -> [[TrendTag]] {
        guard columnCount > 0 else { return [] }
        var result = Array(repeating: [TrendTag](), count: columnCount)
        var columnHeights = Array(repeating: CGFloat(0), count: columnCount)

        for item in store.trendTags {
            if let minIndex = columnHeights.indices.min(by: { columnHeights[$0] < columnHeights[$1] }) {
                result[minIndex].append(item)
                columnHeights[minIndex] += trendTagHeight(item)
            }
        }
        return result
    }

    func recommendedSearchTagColumns(columnCount: Int) -> [[TrendTag]] {
        guard columnCount > 0 else { return [] }
        var result = Array(repeating: [TrendTag](), count: columnCount)
        for (index, item) in store.recommendedSearchTags.enumerated() {
            result[index % columnCount].append(item)
        }
        return result
    }

    // MARK: - Search

    func performSearch(
        word: String,
        translatedName: String? = nil,
        path: Binding<NavigationPath>
    ) {
        let normalizedWord = normalizedSearchQuery(word)
        guard !normalizedWord.isEmpty else { return }

        store.addHistory(SearchTag(name: normalizedWord, translatedName: translatedName))
        store.searchText = normalizedWord

        let preloadToken = UUID()
        SearchResultStore.scheduleSearchEntryPseudoPopularPreload(
            word: normalizedWord,
            token: preloadToken,
            isPremium: accountStore.currentAccount?.isPremium == 1,
            defaultSort: SearchSortOption(rawValue: userSettingStore.userSetting.defaultSearchSort) ?? .dateDesc
        )

        path.wrappedValue = NavigationPath()
        path.wrappedValue.append(SearchResultTarget(word: normalizedWord, preloadToken: preloadToken))
    }

    // MARK: - Pending Illust Loading

    func loadIllustDetail(
        illustId: Int,
        path: Binding<NavigationPath>
    ) async {
        isLoadingDetail = true
        defer { isLoadingDetail = false }

        do {
            let illust = try await PixivAPI.shared.illustAPI.getIllustDetail(illustId: illustId)
            await MainActor.run {
                path.wrappedValue.append(illust)
            }
        } catch let error as NetworkError {
            if case .httpError(404) = error {
                errorMessage = String(localized: "没有找到插画") + " (ID: \(illustId))"
                show404Error = true
            }
        } catch {
            Logger.search.error("Failed to load illust: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - SauceNAO Search

    func startSauceNaoSearch() {
        guard accountStore.isLoggedIn else {
            showSauceToastMessage(String(localized: "请先登录"))
            return
        }
        #if os(iOS)
        selectedPhotoItem = nil
        #else
        showImageFileImporter = true
        #endif
    }

    func showSauceToastMessage(_ message: String) {
        sauceToastMessage = message
        showSauceToast = true
    }

    func handleImportedImage(_ result: Result<[URL], Error>) {
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
    func searchWithImageURL(_ url: URL) async {
        do {
            let data = try await Task.detached {
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                return try Data(contentsOf: url)
            }.value
            let fileName = url.lastPathComponent.isEmpty ? "image.jpg" : url.lastPathComponent
            await searchWithImageData(data, fileName: fileName)
        } catch {
            showSauceToastMessage("读取图片失败: \(error.localizedDescription)")
        }
    }

    @MainActor
    func searchWithImageData(_ data: Data, fileName: String) {
        let requestId = SauceNaoSearchRequestStore.shared.enqueue(imageData: data, fileName: fileName)
        pendingSauceNaoTarget = SauceNaoResultTarget(requestId: requestId)
    }

    #if os(iOS)
    func handleSelectedPhotoItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                guard let imageData = try await item.loadTransferable(type: Data.self) else {
                    await MainActor.run {
                        showSauceToastMessage(String(localized: "读取图片失败"))
                    }
                    return
                }
                await MainActor.run {
                    searchWithImageData(imageData, fileName: "photo.jpg")
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
}

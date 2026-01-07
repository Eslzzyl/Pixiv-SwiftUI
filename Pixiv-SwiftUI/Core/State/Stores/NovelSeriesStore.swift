import Foundation
import Observation

@Observable
@MainActor
final class NovelSeriesStore {
    let seriesId: Int
    
    var seriesDetail: NovelSeriesDetail?
    var novels: [Novel] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    var nextUrl: String?
    
    init(seriesId: Int) {
        self.seriesId = seriesId
    }
    
    func fetch() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await PixivAPI.shared.novelAPI?.getNovelSeries(seriesId: seriesId)
            
            if let response = response {
                seriesDetail = response.novelSeriesDetail
                novels = response.novels
                nextUrl = response.nextUrl
            }
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func loadMore() async {
        guard !isLoadingMore, let nextUrl = nextUrl else { return }
        
        isLoadingMore = true
        
        do {
            let response = try await PixivAPI.shared.novelAPI?.getNovelSeriesByURL(nextUrl)
            
            if let response = response {
                novels.append(contentsOf: response.novels)
                self.nextUrl = response.nextUrl
            }
            
            isLoadingMore = false
        } catch {
            errorMessage = error.localizedDescription
            isLoadingMore = false
        }
    }
}

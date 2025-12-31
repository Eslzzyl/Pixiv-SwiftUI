import Foundation
import SwiftUI
import Observation

@Observable
final class UserDetailStore {
    var userDetail: UserDetailResponse?
    var illusts: [Illusts] = []
    var bookmarks: [Illusts] = []
    
    var isLoadingDetail: Bool = false
    var isLoadingIllusts: Bool = false
    var isLoadingBookmarks: Bool = false
    
    var errorMessage: String?
    
    private let userId: String
    private let api = PixivAPI.shared
    
    init(userId: String) {
        self.userId = userId
    }
    
    @MainActor
    func fetchAll() async {
        isLoadingDetail = true
        isLoadingIllusts = true
        isLoadingBookmarks = true
        errorMessage = nil
        
        do {
            async let detail = api.getUserDetail(userId: userId)
            async let illustsData = api.getUserIllusts(userId: userId)
            async let bookmarksData = api.getUserBookmarksIllusts(userId: userId)
            
            let (fetchedDetail, fetchedIllusts, fetchedBookmarksResult) = try await (detail, illustsData, bookmarksData)
            
            self.userDetail = fetchedDetail
            self.illusts = fetchedIllusts
            self.bookmarks = fetchedBookmarksResult.0
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error fetching user detail: \(error)")
        }
        
        isLoadingDetail = false
        isLoadingIllusts = false
        isLoadingBookmarks = false
    }
    
    @MainActor
    func toggleFollow() async {
        guard let detail = userDetail else { return }
        let isFollowed = detail.user.isFollowed
        
        // 乐观更新
        // 注意：这里我们只能更新 userDetail 中的状态，但 UserDetailUser 是 struct，所以我们需要创建一个新的实例
        // 或者我们可以只在 UI 上显示变化，等待 API 成功后再刷新
        // 为了简单起见，我们先假设成功，如果失败再回滚（或者重新获取详情）
        
        do {
            if isFollowed {
                try await api.unfollowUser(userId: userId)
            } else {
                try await api.followUser(userId: userId)
            }
            // 重新获取详情以更新状态
            let newDetail = try await api.getUserDetail(userId: userId)
            self.userDetail = newDetail
        } catch {
            self.errorMessage = "操作失败: \(error.localizedDescription)"
        }
    }
}

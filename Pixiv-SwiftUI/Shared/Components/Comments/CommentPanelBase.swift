import SwiftUI
import Observation

@MainActor
@Observable
final class CommentPanelBase {
    var comments: [Comment] = []
    var isLoadingComments = false
    var commentsError: String?
    var expandedCommentIds = Set<Int>()
    var loadingReplyIds = Set<Int>()
    var repliesDict = [Int: [Comment]]()
    var commentText: String = ""
    var replyToUserName: String?
    var replyToCommentId: Int?
    var isSubmitting = false
    var errorMessage: String?
    var showDeleteAlert = false
    var commentToDelete: Comment?

    let cache: CacheManager
    let expiration: CacheExpiration
    let maxCommentLength: Int
    let cacheKeyProvider: (Int) -> String
    let loadCommentsAPI: (Int) async throws -> CommentResponse
    let postCommentAPI: (Int, String, Int?) async throws -> Void
    let deleteCommentAPI: (Int) async throws -> Void

    init(
        cache: CacheManager = .shared,
        expiration: CacheExpiration = .minutes(10),
        maxCommentLength: Int = 140,
        cacheKeyProvider: @escaping (Int) -> String,
        loadCommentsAPI: @escaping (Int) async throws -> CommentResponse,
        postCommentAPI: @escaping (Int, String, Int?) async throws -> Void,
        deleteCommentAPI: @escaping (Int) async throws -> Void
    ) {
        self.cache = cache
        self.expiration = expiration
        self.maxCommentLength = maxCommentLength
        self.cacheKeyProvider = cacheKeyProvider
        self.loadCommentsAPI = loadCommentsAPI
        self.postCommentAPI = postCommentAPI
        self.deleteCommentAPI = deleteCommentAPI
    }

    var canSubmit: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        commentText.count <= maxCommentLength &&
        !isSubmitting
    }

    func cancelReply() {
        replyToUserName = nil
        replyToCommentId = nil
    }

    func submitComment(entityId: Int) async {
        guard canSubmit else { return }

        let trimmedComment = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            try await postCommentAPI(entityId, trimmedComment, replyToCommentId)
            commentText = ""
            isSubmitting = false
            cancelReply()
            refreshComments(entityId: entityId)
        } catch {
            errorMessage = "发送失败: \(error.localizedDescription)"
            isSubmitting = false
        }
    }

    func loadComments(entityId: Int) async {
        let cacheKey = cacheKeyProvider(entityId)

        if let cached: CommentResponse = cache.get(forKey: cacheKey) {
            comments = cached.comments
            return
        }

        isLoadingComments = true
        commentsError = nil

        do {
            let response = try await loadCommentsAPI(entityId)
            comments = response.comments
            cache.set(response, forKey: cacheKey, expiration: expiration)
            isLoadingComments = false
        } catch {
            commentsError = "加载失败: \(error.localizedDescription)"
            isLoadingComments = false
        }
    }

    func refreshComments(entityId: Int) {
        let cacheKey = cacheKeyProvider(entityId)
        cache.remove(forKey: cacheKey)
        Task {
            await loadComments(entityId: entityId)
        }
    }

    func toggleExpand(for commentId: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedCommentIds.contains(commentId) {
                expandedCommentIds.remove(commentId)
            } else {
                expandedCommentIds.insert(commentId)
                if repliesDict[commentId] == nil {
                    loadReplies(for: commentId)
                }
            }
        }
    }

    func loadReplies(for commentId: Int) {
        guard commentId > 0 else { return }

        loadingReplyIds.insert(commentId)

        Task {
            do {
                let response = try await PixivAPI.shared.getIllustCommentsReplies(commentId: commentId)
                repliesDict[commentId] = response.comments
                loadingReplyIds.remove(commentId)
            } catch {
                loadingReplyIds.remove(commentId)
            }
        }
    }

    func handleDeleteComment(_ comment: Comment) {
        guard comment.id != nil else { return }

        guard let commentUserId = comment.user?.id,
              String(commentUserId) == AccountStore.shared.currentUserId else {
            errorMessage = "只能删除自己的评论"
            return
        }

        commentToDelete = comment
        showDeleteAlert = true
    }

    func confirmDeleteComment(entityId: Int) async {
        guard let comment = commentToDelete, let commentId = comment.id else { return }

        showDeleteAlert = false

        do {
            try await deleteCommentAPI(commentId)
            comments.removeAll { $0.id == commentId }
            for key in repliesDict.keys {
                repliesDict[key] = repliesDict[key]?.filter { $0.id != commentId }
            }
            let cacheKey = cacheKeyProvider(entityId)
            cache.remove(forKey: cacheKey)
            commentToDelete = nil
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }
}

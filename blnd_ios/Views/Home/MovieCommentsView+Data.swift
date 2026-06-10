import SwiftUI

// MARK: - Data Methods

extension MovieCommentsView {
    @MainActor
    func loadComments(refresh: Bool = false) async {
        if refresh {
            isLoading = true
            error = nil
        }
        do {
            let response = try await CommentsAPI.getComments(
                tmdbId: tmdbId,
                limit: 20,
                offset: refresh ? 0 : comments.count
            )
            if refresh {
                comments = response.results
            } else {
                comments += response.results
            }
            total = response.total
        } catch {
            self.error = "Could not load comments."
        }
        isLoading = false
    }

    @MainActor
    func loadMore() async {
        guard !isLoadingMore, comments.count < total else { return }
        isLoadingMore = true
        do {
            let response = try await CommentsAPI.getComments(tmdbId: tmdbId, limit: 20, offset: comments.count)
            comments += response.results
            total = response.total
        } catch {
            // Non-fatal — user can tap again
        }
        isLoadingMore = false
    }

    @MainActor
    func sendComment() async {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxCommentLength, !isSending else { return }
        isSending = true
        sendError = nil

        if let editing = editingComment {
            do {
                let updated = try await CommentsAPI.editComment(id: editing.id, body: trimmed)
                applyEdit(updated)
                editingComment = nil
                draftText = ""
            } catch {
                sendError = "Couldn't save your edit. Try again."
            }
        } else if let replying = replyingTo {
            do {
                let newReply = try await CommentsAPI.createReply(parentId: replying.id, body: trimmed)
                // The backend reparents replies to their top-level comment, so locate the
                // parent by the returned parentId — works whether you replied to a
                // top-level comment or to another reply.
                let parentId = newReply.parentId ?? replying.id
                if let idx = comments.firstIndex(where: { $0.id == parentId }) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        comments[idx].replies.append(newReply)
                        expandedThreads.insert(parentId)
                    }
                }
                replyingTo = nil
                draftText = ""
            } catch {
                sendError = "Couldn't post your reply. Try again."
            }
        } else {
            do {
                let newComment = try await CommentsAPI.createComment(tmdbId: tmdbId, body: trimmed)
                withAnimation(.easeInOut(duration: 0.3)) {
                    comments.insert(newComment, at: 0)
                    total += 1
                }
                draftText = ""
            } catch {
                sendError = "Couldn't post your comment. Try again."
            }
        }

        isSending = false
        // Dismiss keyboard
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    /// Updates an edited comment in place (top-level or reply) without a full reload.
    @MainActor
    func applyEdit(_ updated: CommentResponse) {
        if let idx = comments.firstIndex(where: { $0.id == updated.id }) {
            comments[idx].body = updated.body
            comments[idx].isEdited = updated.isEdited
            return
        }
        for parentIdx in comments.indices {
            if let replyIdx = comments[parentIdx].replies.firstIndex(where: { $0.id == updated.id }) {
                comments[parentIdx].replies[replyIdx].body = updated.body
                comments[parentIdx].replies[replyIdx].isEdited = updated.isEdited
                return
            }
        }
    }

    @MainActor
    func toggleLike(on comment: CommentResponse) {
        // Try top-level first
        if let idx = comments.firstIndex(where: { $0.id == comment.id }) {
            let wasLiked = comments[idx].likedByMe
            let prevCount = comments[idx].likeCount
            comments[idx].likedByMe = !wasLiked
            comments[idx].likeCount = wasLiked ? max(0, prevCount - 1) : prevCount + 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task {
                do {
                    let result = wasLiked
                        ? try await CommentsAPI.unlikeComment(id: comment.id)
                        : try await CommentsAPI.likeComment(id: comment.id)
                    if let refreshIdx = comments.firstIndex(where: { $0.id == comment.id }) {
                        comments[refreshIdx].likeCount = result.likeCount
                        comments[refreshIdx].likedByMe = result.likedByMe
                    }
                } catch {
                    // Silent rollback
                    if let rollbackIdx = comments.firstIndex(where: { $0.id == comment.id }) {
                        comments[rollbackIdx].likedByMe = wasLiked
                        comments[rollbackIdx].likeCount = prevCount
                    }
                }
            }
            return
        }

        // Try nested replies
        for parentIdx in comments.indices {
            if let replyIdx = comments[parentIdx].replies.firstIndex(where: { $0.id == comment.id }) {
                let wasLiked = comments[parentIdx].replies[replyIdx].likedByMe
                let prevCount = comments[parentIdx].replies[replyIdx].likeCount
                comments[parentIdx].replies[replyIdx].likedByMe = !wasLiked
                comments[parentIdx].replies[replyIdx].likeCount = wasLiked ? max(0, prevCount - 1) : prevCount + 1
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task {
                    do {
                        let result = wasLiked
                            ? try await CommentsAPI.unlikeComment(id: comment.id)
                            : try await CommentsAPI.likeComment(id: comment.id)
                        updateReplyLike(commentId: comment.id, count: result.likeCount, liked: result.likedByMe)
                    } catch {
                        // Silent rollback
                        updateReplyLike(commentId: comment.id, count: prevCount, liked: wasLiked)
                    }
                }
                return
            }
        }
    }

    /// Writes a like count/state back onto a nested reply, locating it across all threads.
    @MainActor
    private func updateReplyLike(commentId: Int, count: Int, liked: Bool) {
        guard let parentIdx = comments.firstIndex(where: { parent in
            parent.replies.contains(where: { $0.id == commentId })
        }), let replyIdx = comments[parentIdx].replies.firstIndex(where: { $0.id == commentId }) else {
            return
        }
        comments[parentIdx].replies[replyIdx].likeCount = count
        comments[parentIdx].replies[replyIdx].likedByMe = liked
    }

    func startEdit(_ comment: CommentResponse) {
        editingComment = comment
        draftText = comment.body
        replyingTo = nil
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            isComposeFocused = true
        }
    }

    func startReply(_ comment: CommentResponse) {
        replyingTo = comment
        editingComment = nil
        draftText = "@\(comment.displayUsername) "
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            isComposeFocused = true
        }
    }

    func confirmDelete(_ comment: CommentResponse) {
        commentToDelete = comment
        showDeleteConfirm = true
    }

    @MainActor
    func deleteComment(_ comment: CommentResponse) async {
        do {
            try await CommentsAPI.deleteComment(id: comment.id)
            // Replace with tombstone at top-level
            if let idx = comments.firstIndex(where: { $0.id == comment.id }) {
                comments[idx] = tombstone(for: comment, keepReplies: true)
                return
            }
            // Replace with tombstone in nested replies
            for parentIdx in comments.indices {
                if let replyIdx = comments[parentIdx].replies.firstIndex(where: { $0.id == comment.id }) {
                    comments[parentIdx].replies[replyIdx] = tombstone(for: comment, keepReplies: false)
                    return
                }
            }
        } catch {
            // Silent — user can try again via context menu
        }
    }

    /// Builds the soft-deleted placeholder shown after deletion.
    private func tombstone(for comment: CommentResponse, keepReplies: Bool) -> CommentResponse {
        CommentResponse(
            id: comment.id,
            tmdbId: comment.tmdbId,
            parentId: comment.parentId,
            replyToUserId: nil,
            replyToUsername: nil,
            userId: nil,
            username: nil,
            avatarUrl: nil,
            body: "[deleted]",
            likeCount: comment.likeCount,
            likedByMe: comment.likedByMe,
            commenterRating: nil,
            isEdited: false,
            createdAt: comment.createdAt,
            replies: keepReplies ? comment.replies : []
        )
    }
}

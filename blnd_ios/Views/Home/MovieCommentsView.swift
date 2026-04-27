import SwiftUI

// MARK: - MovieCommentsView

struct MovieCommentsView: View {
    let tmdbId: Int
    let movieTitle: String
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthState.self) private var authState

    @State private var comments: [CommentResponse] = []
    @State private var total: Int = 0
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var error: String?
    @State private var draftText = ""
    @State private var isSending = false
    @State private var replyingTo: CommentResponse?
    @State private var editingComment: CommentResponse?
    @State private var showDeleteConfirm = false
    @State private var commentToDelete: CommentResponse?
    @FocusState private var isComposeFocused: Bool

    var currentUserId: String { authState.currentUser?.id ?? "" }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                            } else if let err = error {
                                VStack(spacing: 12) {
                                    Text(err)
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.textMuted)
                                        .multilineTextAlignment(.center)
                                    Button("Try Again") {
                                        Task { await loadComments() }
                                    }
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            } else if comments.isEmpty {
                                Text("No comments yet. Be the first!")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.textMuted)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                            } else {
                                ForEach(comments) { comment in
                                    VStack(spacing: 0) {
                                        CommentRowView(
                                            comment: comment,
                                            currentUserId: currentUserId,
                                            onReply: { startReply($0) },
                                            onEdit: { startEdit($0) },
                                            onDelete: { confirmDelete($0) },
                                            onLike: { toggleLike(on: $0) }
                                        )
                                        .id(comment.id)
                                        .padding(.horizontal, 16)

                                        ForEach(comment.replies) { reply in
                                            ReplyRowView(
                                                comment: reply,
                                                currentUserId: currentUserId,
                                                onEdit: { startEdit($0) },
                                                onDelete: { confirmDelete($0) },
                                                onLike: { toggleLike(on: $0) }
                                            )
                                            .id(reply.id)
                                            .padding(.horizontal, 16)
                                            .padding(.leading, 40)
                                        }
                                    }
                                }

                                // Load-more button
                                if comments.count < total {
                                    if isLoadingMore {
                                        ProgressView()
                                            .tint(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                    } else {
                                        Button {
                                            Task { await loadMore() }
                                        } label: {
                                            Text("Load more comments (\(total - comments.count))")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 80)
                    }
                    .refreshable {
                        await loadComments(refresh: true)
                    }
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .onChange(of: comments.count) { _, _ in
                        // Proxy used via sendComment closures
                        _ = proxy
                    }
                    .onAppear {
                        Task {
                            await sendCommentScrollProxy(proxy)
                        }
                    }
                    .background(AppTheme.card)
                    .task {
                        await loadComments()
                    }
                    .environment(\.scrollProxy, proxy)
                }

                // Compose bar overlay
                composeBar
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .background(AppTheme.card)
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .confirmationDialog(
                "Delete comment?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let comment = commentToDelete {
                        Task { await deleteComment(comment) }
                    }
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    // MARK: - Compose Bar

    private var composeBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(AppTheme.border)

            // Reply / Edit banner
            if let replying = replyingTo {
                withAnimation(.easeInOut(duration: 0.2)) {
                    replyBanner(username: replying.displayUsername)
                }
            } else if editingComment != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    editBanner
                }
            }

            // Input row
            HStack(alignment: .center, spacing: 8) {
                TextField("Add a comment...", text: $draftText, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($isComposeFocused)

                // Character count (only shown >= 900)
                if draftText.count >= 900 {
                    Text("\(1000 - draftText.count)")
                        .font(.system(size: 12))
                        .foregroundStyle(draftText.count >= 980 ? AppTheme.destructive : AppTheme.textDim)
                }

                // Send button
                Button {
                    let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, draftText.count <= 1000, !isSending else { return }
                    Task { await sendComment() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || draftText.count > 1000
                                || isSending
                                ? AppTheme.textDim
                                : .white
                        )
                }
                .disabled(
                    draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || draftText.count > 1000
                        || isSending
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.card)
        }
        .background(AppTheme.card)
    }

    private func replyBanner(username: String) -> some View {
        HStack {
            Text("Replying to @\(username)")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textMuted)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    replyingTo = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textDim)
            }
            .accessibilityLabel("Cancel")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.cardSecondary)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var editBanner: some View {
        HStack {
            Text("Editing comment")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textMuted)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    editingComment = nil
                    draftText = ""
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textDim)
            }
            .accessibilityLabel("Cancel")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.cardSecondary)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Data Methods

extension MovieCommentsView {

    @MainActor
    func loadComments(refresh: Bool = false) async {
        if refresh {
            isLoading = true
            error = nil
        }
        do {
            let response = try await CommentsAPI.getComments(tmdbId: tmdbId, limit: 20, offset: refresh ? 0 : comments.count)
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
        guard !trimmed.isEmpty, !isSending else { return }
        isSending = true

        if let editing = editingComment {
            do {
                _ = try await CommentsAPI.editComment(id: editing.id, body: trimmed)
                // Reload to get fresh state (isEdited is let, so local mutation isn't clean)
                await loadComments(refresh: true)
                editingComment = nil
                draftText = ""
            } catch {
                // Silent — leave draft intact so user can retry
            }
        } else if let replying = replyingTo {
            do {
                let newReply = try await CommentsAPI.createReply(parentId: replying.id, body: trimmed)
                if let idx = comments.firstIndex(where: { $0.id == replying.id }) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        comments[idx].replies.append(newReply)
                    }
                }
                replyingTo = nil
                draftText = ""
            } catch {
                // Silent — leave draft intact
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
                // Silent — leave draft intact
            }
        }

        isSending = false
        // Dismiss keyboard
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // Scroll proxy helper — no-op when called from onAppear, used contextually
    func sendCommentScrollProxy(_ proxy: ScrollViewProxy) async {
        // Intentional no-op: proxy stored via .environment for sendComment calls
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
                        if let pi = self.comments.firstIndex(where: { c in
                            c.replies.contains(where: { $0.id == comment.id })
                        }), let ri = self.comments[pi].replies.firstIndex(where: { $0.id == comment.id }) {
                            self.comments[pi].replies[ri].likeCount = result.likeCount
                            self.comments[pi].replies[ri].likedByMe = result.likedByMe
                        }
                    } catch {
                        // Silent rollback
                        if let pi = self.comments.firstIndex(where: { c in
                            c.replies.contains(where: { $0.id == comment.id })
                        }), let ri = self.comments[pi].replies.firstIndex(where: { $0.id == comment.id }) {
                            self.comments[pi].replies[ri].likedByMe = wasLiked
                            self.comments[pi].replies[ri].likeCount = prevCount
                        }
                    }
                }
                return
            }
        }
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
        draftText = ""
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
                let tombstone = CommentResponse(
                    id: comment.id,
                    tmdbId: comment.tmdbId,
                    parentId: comment.parentId,
                    userId: nil,
                    username: nil,
                    avatarUrl: nil,
                    body: "[deleted]",
                    likeCount: comment.likeCount,
                    likedByMe: comment.likedByMe,
                    commenterRating: nil,
                    isEdited: false,
                    createdAt: comment.createdAt,
                    replies: comment.replies
                )
                comments[idx] = tombstone
                return
            }
            // Replace with tombstone in nested replies
            for parentIdx in comments.indices {
                if let replyIdx = comments[parentIdx].replies.firstIndex(where: { $0.id == comment.id }) {
                    let tombstone = CommentResponse(
                        id: comment.id,
                        tmdbId: comment.tmdbId,
                        parentId: comment.parentId,
                        userId: nil,
                        username: nil,
                        avatarUrl: nil,
                        body: "[deleted]",
                        likeCount: comment.likeCount,
                        likedByMe: comment.likedByMe,
                        commenterRating: nil,
                        isEdited: false,
                        createdAt: comment.createdAt,
                        replies: []
                    )
                    comments[parentIdx].replies[replyIdx] = tombstone
                    return
                }
            }
        } catch {
            // Silent — user can try again via context menu
        }
    }
}

// MARK: - ScrollProxy Environment Key

private struct ScrollProxyKey: EnvironmentKey {
    static var defaultValue: ScrollViewProxy? = nil
}

extension EnvironmentValues {
    var scrollProxy: ScrollViewProxy? {
        get { self[ScrollProxyKey.self] }
        set { self[ScrollProxyKey.self] = newValue }
    }
}

// MARK: - CommentRowView

private struct CommentRowView: View {
    let comment: CommentResponse
    let currentUserId: String
    let onReply: (CommentResponse) -> Void
    let onEdit: (CommentResponse) -> Void
    let onDelete: (CommentResponse) -> Void
    let onLike: (CommentResponse) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            AvatarView(url: comment.avatarUrl, size: 32)

            VStack(alignment: .leading, spacing: 4) {
                if comment.isDeleted {
                    Text("[deleted]")
                        .font(.system(size: 14).italic())
                        .foregroundStyle(AppTheme.textDim)
                } else {
                    // Username row
                    HStack(spacing: 6) {
                        Text(comment.displayUsername)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)

                        if let rating = comment.commenterRating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 7))
                                Text(
                                    rating.truncatingRemainder(dividingBy: 1) == 0
                                        ? String(format: "%.0f", rating)
                                        : String(format: "%.1f", rating)
                                )
                                .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.7))
                            .clipShape(Capsule())
                        }

                        Spacer()
                    }

                    // Body + edited indicator
                    VStack(alignment: .leading, spacing: 0) {
                        Text(comment.body)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textMuted)
                            .lineSpacing(3)
                        if comment.isEdited {
                            Text(" (edited)")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textDim)
                        }
                    }

                    // Action row
                    HStack(spacing: 12) {
                        Text(comment.timeAgo)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textDim)

                        Button("Reply") {
                            onReply(comment)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textDim)

                        LikeButton(
                            likedByMe: comment.likedByMe,
                            likeCount: comment.likeCount
                        ) {
                            onLike(comment)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            if comment.userId == currentUserId && !comment.isDeleted {
                Button {
                    onEdit(comment)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDelete(comment)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - ReplyRowView

private struct ReplyRowView: View {
    let comment: CommentResponse
    let currentUserId: String
    let onEdit: (CommentResponse) -> Void
    let onDelete: (CommentResponse) -> Void
    let onLike: (CommentResponse) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            AvatarView(url: comment.avatarUrl, size: 24)

            VStack(alignment: .leading, spacing: 4) {
                if comment.isDeleted {
                    Text("[deleted]")
                        .font(.system(size: 13).italic())
                        .foregroundStyle(AppTheme.textDim)
                } else {
                    // Username row
                    HStack(spacing: 6) {
                        Text(comment.displayUsername)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)

                        if let rating = comment.commenterRating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 7))
                                Text(
                                    rating.truncatingRemainder(dividingBy: 1) == 0
                                        ? String(format: "%.0f", rating)
                                        : String(format: "%.1f", rating)
                                )
                                .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.7))
                            .clipShape(Capsule())
                        }

                        Spacer()
                    }

                    // Body + edited indicator
                    VStack(alignment: .leading, spacing: 0) {
                        Text(comment.body)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textMuted)
                            .lineSpacing(3)
                        if comment.isEdited {
                            Text(" (edited)")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textDim)
                        }
                    }

                    // Action row (no Reply button for replies)
                    HStack(spacing: 12) {
                        Text(comment.timeAgo)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textDim)

                        LikeButton(
                            likedByMe: comment.likedByMe,
                            likeCount: comment.likeCount
                        ) {
                            onLike(comment)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            if comment.userId == currentUserId && !comment.isDeleted {
                Button {
                    onEdit(comment)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDelete(comment)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - LikeButton

private struct LikeButton: View {
    let likedByMe: Bool
    let likeCount: Int
    let onToggle: () -> Void

    @State private var scale: CGFloat = 1.0

    var body: some View {
        Button {
            onToggle()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scale = 1.25
            }
            Task {
                try? await Task.sleep(nanoseconds: 150_000_000)
                withAnimation {
                    scale = 1.0
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: likedByMe ? "heart.fill" : "heart")
                    .font(.system(size: 14))
                    .foregroundStyle(likedByMe ? .red : AppTheme.textDim)
                    .scaleEffect(scale)

                if likeCount > 0 {
                    Text("\(likeCount)")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textDim)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            likedByMe
                ? "Unlike comment, \(likeCount) likes"
                : likeCount > 0 ? "Like comment, \(likeCount) likes" : "Like comment"
        )
    }
}

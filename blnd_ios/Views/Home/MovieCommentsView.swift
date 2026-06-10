import SwiftUI

// MARK: - MovieCommentsView

struct MovieCommentsView: View {
    let tmdbId: Int
    let movieTitle: String
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthState.self) private var authState

    @State var comments: [CommentResponse] = []
    @State var total: Int = 0
    @State var isLoading = true
    @State var isLoadingMore = false
    @State var error: String?
    @State var draftText = ""
    @State var isSending = false
    @State var replyingTo: CommentResponse?
    @State var editingComment: CommentResponse?
    @State var showDeleteConfirm = false
    @State var commentToDelete: CommentResponse?
    @State var sendError: String?
    @State var expandedThreads: Set<Int> = []
    @FocusState var isComposeFocused: Bool

    /// Must match the backend `body` max_length (app.comments.schemas).
    let maxCommentLength = 250

    var currentUserId: String {
        authState.currentUser?.id ?? ""
    }

    private var trimmedDraft: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !trimmedDraft.isEmpty && draftText.count <= maxCommentLength && !isSending
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else if let err = error {
                            errorState(err)
                        } else if comments.isEmpty {
                            Text("No comments yet. Be the first!")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textMuted)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            ForEach(comments) { comment in
                                VStack(alignment: .leading, spacing: 0) {
                                    CommentRowView(
                                        comment: comment,
                                        currentUserId: currentUserId,
                                        isReply: false,
                                        onReply: { startReply($0) },
                                        onEdit: { startEdit($0) },
                                        onDelete: { confirmDelete($0) },
                                        onLike: { toggleLike(on: $0) }
                                    )
                                    .id(comment.id)
                                    .padding(.horizontal, 16)

                                    if !comment.replies.isEmpty {
                                        replyThread(for: comment)
                                    }
                                }
                            }
                            loadMoreButton
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 80)
                }
                .refreshable {
                    await loadComments(refresh: true)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .background(AppTheme.card)
                .task {
                    await loadComments()
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

    // MARK: - Subviews

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
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
    }

    /// Collapsible "View N replies" thread under a top-level comment.
    @ViewBuilder
    private func replyThread(for comment: CommentResponse) -> some View {
        let isExpanded = expandedThreads.contains(comment.id)
        let count = comment.replies.count

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded {
                    expandedThreads.remove(comment.id)
                } else {
                    expandedThreads.insert(comment.id)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(AppTheme.border)
                    .frame(width: 20, height: 1)
                Text(isExpanded ? "Hide replies" : "View \(count) \(count == 1 ? "reply" : "replies")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textDim)
            }
        }
        .padding(.leading, 56)
        .padding(.vertical, 4)

        if isExpanded {
            ForEach(comment.replies) { reply in
                CommentRowView(
                    comment: reply,
                    currentUserId: currentUserId,
                    isReply: true,
                    onReply: { startReply($0) },
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

    @ViewBuilder
    private var loadMoreButton: some View {
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

            // Send-failure message
            if let sendError {
                Text(sendError)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(AppTheme.cardSecondary)
                    .transition(.opacity)
            }

            // Input row
            HStack(alignment: .center, spacing: 8) {
                TextField("Add a comment...", text: $draftText, axis: .vertical)
                    .lineLimit(1 ... 5)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($isComposeFocused)
                    .onChange(of: draftText) { _, _ in
                        if sendError != nil { sendError = nil }
                    }

                // Character count (shown as you approach the limit)
                if draftText.count >= maxCommentLength - 50 {
                    Text("\(maxCommentLength - draftText.count)")
                        .font(.system(size: 12))
                        .foregroundStyle(draftText.count > maxCommentLength ? AppTheme.destructive : AppTheme.textDim)
                }

                // Send button
                Button {
                    guard canSend else { return }
                    Task { await sendComment() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(canSend ? .white : AppTheme.textDim)
                }
                .disabled(!canSend)
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

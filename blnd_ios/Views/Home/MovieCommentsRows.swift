import SwiftUI

// MARK: - CommentRowView

/// A single comment or reply. `isReply` only adjusts sizing and shows the
/// "replying to" attribution; the layout is otherwise identical.
struct CommentRowView: View {
    let comment: CommentResponse
    let currentUserId: String
    let isReply: Bool
    let onReply: (CommentResponse) -> Void
    let onEdit: (CommentResponse) -> Void
    let onDelete: (CommentResponse) -> Void
    let onLike: (CommentResponse) -> Void

    private var avatarSize: CGFloat {
        isReply ? 24 : 32
    }

    private var textSize: CGFloat {
        isReply ? 13 : 14
    }

    @State private var showReportDialog = false
    @State private var showBlockConfirm = false
    @State private var moderationNotice: String?

    private var canModify: Bool {
        comment.userId == currentUserId && !comment.isDeleted
    }

    private var canModerate: Bool {
        CommentModeration.canModerate(
            authorId: comment.userId, currentUserId: currentUserId, isDeleted: comment.isDeleted
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            AvatarView(url: comment.avatarUrl, size: avatarSize)

            VStack(alignment: .leading, spacing: 4) {
                if comment.isDeleted {
                    Text("[deleted]")
                        .font(.system(size: textSize).italic())
                        .foregroundStyle(AppTheme.textDim)
                } else {
                    usernameRow
                    bodyBlock
                    actionRow
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            if canModify {
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
            if canModerate {
                moderationButtons
            }
        }
        .confirmationDialog("Report this comment", isPresented: $showReportDialog, titleVisibility: .visible) {
            ForEach(CommentModeration.Category.allCases) { category in
                Button(category.rawValue) { submitReport(category) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Block \(comment.displayUsername)?", isPresented: $showBlockConfirm) {
            Button("Block", role: .destructive) { blockAuthor() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't see each other's activity. You can unblock from Settings.")
        }
        .alert(
            moderationNotice ?? "",
            isPresented: Binding(get: { moderationNotice != nil }, set: { if !$0 { moderationNotice = nil } })
        ) {
            Button("OK", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var moderationButtons: some View {
        Button {
            showReportDialog = true
        } label: {
            Label("Report", systemImage: "flag")
        }
        .accessibilityIdentifier("comment.report")
        Button(role: .destructive) {
            showBlockConfirm = true
        } label: {
            Label("Block user", systemImage: "hand.raised")
        }
        .accessibilityIdentifier("comment.block")
    }

    private func submitReport(_ category: CommentModeration.Category) {
        Task {
            // Non-fatal on failure: always acknowledge so the user knows we heard them.
            try? await CommentModeration.report(comment, category: category)
            moderationNotice = "Thanks. We'll review this comment within 24 hours."
        }
    }

    private func blockAuthor() {
        guard let authorId = comment.userId else { return }
        Task {
            do {
                try await FriendsService.blockUser(userId: authorId)
                moderationNotice = "\(comment.displayUsername) is blocked."
            } catch {
                moderationNotice = "Couldn't block right now. Please try again."
            }
        }
    }

    private var usernameRow: some View {
        HStack(spacing: 6) {
            Text(comment.displayUsername)
                .font(.system(size: textSize, weight: .semibold))
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
    }

    private var bodyBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(comment.body)
                .font(.system(size: textSize))
                .foregroundStyle(AppTheme.textMuted)
                .lineSpacing(3)
            if comment.isEdited {
                Text(" (edited)")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textDim)
            }
        }
    }

    private var actionRow: some View {
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

            if canModerate {
                Menu {
                    moderationButtons
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textDim)
                        .frame(width: 28, height: 20)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("comment.more")
            }
        }
    }
}

// MARK: - LikeButton

struct LikeButton: View {
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

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

    private var canModify: Bool {
        comment.userId == currentUserId && !comment.isDeleted
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

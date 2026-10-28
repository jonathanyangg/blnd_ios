import Foundation

/// Report / block helpers for user-generated comments (App Store guideline 1.2).
/// Reports go through the existing `POST /reports` (reported user + reason); the
/// reason carries the comment id so moderators can find the content.
enum CommentModeration {
    static let maxReasonLength = 200

    enum Category: String, CaseIterable, Identifiable {
        case spam = "Spam"
        case harassment = "Harassment"
        case hate = "Hate speech"
        case spoiler = "Spoilers"
        case other = "Other"

        var id: String { rawValue }
    }

    static func canModerate(authorId: String?, currentUserId: String, isDeleted: Bool) -> Bool {
        guard let authorId, !isDeleted else { return false }
        return authorId != currentUserId
    }

    static func reportReason(category: Category, commentId: Int, body: String) -> String {
        let head = "Comment #\(commentId) [\(category.rawValue)]"
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return head }
        let room = maxReasonLength - head.count - 2
        guard room > 0 else { return String(head.prefix(maxReasonLength)) }
        return "\(head): \(trimmed.prefix(room))"
    }

    static func report(_ comment: CommentResponse, category: Category) async throws {
        guard let authorId = comment.userId else { return }
        try await FriendsAPI.reportUser(
            userId: authorId,
            reason: reportReason(category: category, commentId: comment.id, body: comment.body)
        )
    }
}

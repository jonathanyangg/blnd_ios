import Foundation

/// Comments endpoints: list, create, reply, edit, delete, like, unlike
enum CommentsAPI {
    /// GET /comments/?tmdb_id=N&limit=N&offset=N — list top-level comments with replies
    static func getComments(tmdbId: Int, limit: Int = 20, offset: Int = 0) async throws -> CommentsListResponse {
        try await APIClient.shared.request(
            endpoint: "/comments/?tmdb_id=\(tmdbId)&limit=\(limit)&offset=\(offset)",
            authenticated: true
        )
    }

    /// POST /comments/ — post a new top-level comment
    static func createComment(tmdbId: Int, body: String) async throws -> CommentResponse {
        let req = CreateCommentRequest(tmdbId: tmdbId, body: body)
        return try await APIClient.shared.request(
            endpoint: "/comments/",
            method: "POST",
            body: req,
            authenticated: true
        )
    }

    /// POST /comments/{parentId}/reply — reply to an existing comment
    static func createReply(parentId: Int, body: String) async throws -> CommentResponse {
        let req = CreateReplyRequest(body: body)
        return try await APIClient.shared.request(
            endpoint: "/comments/\(parentId)/reply",
            method: "POST",
            body: req,
            authenticated: true
        )
    }

    /// PATCH /comments/{id} — edit own comment body
    static func editComment(id: Int, body: String) async throws -> CommentResponse {
        let req = EditCommentRequest(body: body)
        return try await APIClient.shared.request(
            endpoint: "/comments/\(id)",
            method: "PATCH",
            body: req,
            authenticated: true
        )
    }

    /// DELETE /comments/{id} — soft-delete own comment
    static func deleteComment(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/comments/\(id)",
            method: "DELETE",
            authenticated: true
        )
    }

    /// POST /comments/{id}/like — like a comment
    static func likeComment(id: Int) async throws -> LikeResponse {
        try await APIClient.shared.request(
            endpoint: "/comments/\(id)/like",
            method: "POST",
            authenticated: true
        )
    }

    /// DELETE /comments/{id}/like — unlike a comment
    static func unlikeComment(id: Int) async throws -> LikeResponse {
        try await APIClient.shared.request(
            endpoint: "/comments/\(id)/like",
            method: "DELETE",
            authenticated: true
        )
    }
}

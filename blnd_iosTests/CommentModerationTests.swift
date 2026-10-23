import Foundation
import Testing
@testable import blnd_ios

struct CommentModerationTests {
    @Test func reasonIncludesCommentIdAndCategory() {
        let r = CommentModeration.reportReason(category: .spam, commentId: 42, body: "buy now")
        #expect(r.hasPrefix("Comment #42 [Spam]"))
        #expect(r.contains("buy now"))
    }

    @Test func reasonNeverExceedsBackendLimit() {
        let long = String(repeating: "x", count: 1000)
        let r = CommentModeration.reportReason(category: .harassment, commentId: 7, body: long)
        #expect(r.count <= CommentModeration.maxReasonLength)
        #expect(!r.isEmpty)
    }

    @Test func emptyBodyStillProducesReason() {
        let r = CommentModeration.reportReason(category: .other, commentId: 1, body: "  ")
        #expect(r == "Comment #1 [Other]")
    }

    @Test func cannotModerateOwnOrDeletedOrAnonymousComments() {
        #expect(CommentModeration.canModerate(authorId: "me", currentUserId: "me", isDeleted: false) == false)
        #expect(CommentModeration.canModerate(authorId: "u2", currentUserId: "me", isDeleted: true) == false)
        #expect(CommentModeration.canModerate(authorId: nil, currentUserId: "me", isDeleted: false) == false)
        #expect(CommentModeration.canModerate(authorId: "u2", currentUserId: "me", isDeleted: false) == true)
    }
}

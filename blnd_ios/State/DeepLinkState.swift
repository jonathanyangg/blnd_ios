import SwiftUI

enum DeepLink: Equatable {
    case friendRequests
    case groupDetail(groupId: Int)
    case movieDetail(tmdbId: Int)
}

struct NotesImportLaunch: Identifiable {
    let text: String
    var id: String { text }
}

@Observable
class DeepLinkState {
    var pending: DeepLink?
    /// Note shared in from the Share Extension. The review screen reads this.
    var pendingNotesText: String?
}

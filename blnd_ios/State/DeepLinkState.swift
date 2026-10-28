import SwiftUI

enum DeepLink: Equatable {
    case friendRequests
    case groupDetail(groupId: Int)
    case movieDetail(tmdbId: Int)
    case comments(tmdbId: Int)
}

@Observable
class DeepLinkState {
    var pending: DeepLink?
}

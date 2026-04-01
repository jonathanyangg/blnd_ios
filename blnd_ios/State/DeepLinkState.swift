import SwiftUI

enum DeepLink: Equatable {
    case friendRequests
    case groupDetail(groupId: Int)
    case movieDetail(tmdbId: Int)
}

@Observable
class DeepLinkState {
    var pending: DeepLink?
}

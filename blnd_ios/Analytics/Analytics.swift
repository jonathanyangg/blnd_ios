import PostHog

/// Thin typed wrapper around PostHogSDK.
/// All analytics calls should go through this enum so event names and property
/// schemas live in one place.
enum Analytics {
    // MARK: - Event names

    private enum EventName {
        static let movieRated = "movie_rated"
        static let ratingUpdated = "rating_updated"
        static let movieUnwatched = "movie_unwatched"
        static let watchlistAdded = "watchlist_added"
        static let watchlistRemoved = "watchlist_removed"
        static let movieHidden = "movie_hidden"
        static let movieInterested = "movie_interested"
        static let movieDetailViewed = "movie_detail_viewed"
        static let trailerPlayed = "trailer_played"
        static let trailerCompleted = "trailer_completed"
        static let reelViewed = "reel_viewed"
        static let feedRefreshed = "feed_refreshed"
        static let feedLoadMore = "feed_load_more"
        static let searchPerformed = "search_performed"
        static let aiSearchPerformed = "ai_search_performed"
        static let paywallShown = "paywall_shown"
        static let paywallDismissed = "paywall_dismissed"
        static let subscriptionStarted = "subscription_started"
        static let subscriptionRestored = "subscription_restored"
        static let friendRequestSent = "friend_request_sent"
        static let friendRequestAccepted = "friend_request_accepted"
        static let friendRequestRejected = "friend_request_rejected"
        static let groupCreated = "group_created"
        static let groupJoined = "group_joined"
        static let groupLeft = "group_left"
        static let tabSwitched = "tab_switched"
        static let pushNotificationTapped = "push_notification_tapped"
        static let onboardingStarted = "onboarding_started"
        static let onboardingStepViewed = "onboarding_step_viewed"
        static let onboardingCompleted = "onboarding_completed"
        static let onboardingDropped = "onboarding_dropped"
        static let tutorialCompleted = "tutorial_completed"
        static let tutorialSkipped = "tutorial_skipped"
        static let errorShown = "error_shown"
    }

    // MARK: - Source enums

    enum RatingSource: String {
        case detail, reels, sheet
    }

    enum WatchlistSource: String {
        case detail, reels, picker, now
    }

    enum FeedSource: String {
        case fyp, discover, blend
    }

    enum DetailSource: String {
        case reels, grid, watchlist, profile, search, notification
        case friendProfile = "friend_profile"
    }

    enum PaywallSource: String {
        case settings, manual
        case aiSearch = "ai_search"
        case groupLimit = "group_limit"
    }

    enum OnboardingStep: String {
        case welcome, signup, genres, complete
        case chooseUsername = "choose_username"
        case rateMovies = "rate_movies"
        case findFriends = "find_friends"
    }

    enum TutorialName: String {
        case reels, blends
        case forYou = "for_you"
    }

    enum PushType: String {
        case digest, unknown
        case friendRequest = "friend_request"
        case friendAccepted = "friend_accepted"
        case groupInvite = "group_invite"
        case groupWatchlist = "group_watchlist"
        case friendActivity = "friend_activity"
    }

    // MARK: - Identity

    static func identify(userId: String, userProperties: [String: Any]? = nil) {
        if let userProperties {
            PostHogSDK.shared.identify(userId, userProperties: userProperties)
        } else {
            PostHogSDK.shared.identify(userId)
        }
    }

    static func reset() {
        PostHogSDK.shared.reset()
    }

    // MARK: - Ratings

    static func movieRated(
        tmdbId: Int,
        rating: Double,
        source: RatingSource,
        fromWatchlist: Bool,
        isUpdate: Bool
    ) {
        PostHogSDK.shared.capture(
            isUpdate ? EventName.ratingUpdated : EventName.movieRated,
            properties: [
                "tmdb_id": tmdbId,
                "rating": rating,
                "source": source.rawValue,
                "from_watchlist": fromWatchlist,
            ]
        )
    }

    static func movieUnwatched(tmdbId: Int, source: RatingSource) {
        PostHogSDK.shared.capture(
            EventName.movieUnwatched,
            properties: ["tmdb_id": tmdbId, "source": source.rawValue]
        )
    }

    // MARK: - Watchlist

    static func watchlistAdded(tmdbId: Int, source: WatchlistSource) {
        PostHogSDK.shared.capture(
            EventName.watchlistAdded,
            properties: ["tmdb_id": tmdbId, "source": source.rawValue]
        )
    }

    static func watchlistRemoved(tmdbId: Int, source: WatchlistSource) {
        PostHogSDK.shared.capture(
            EventName.watchlistRemoved,
            properties: ["tmdb_id": tmdbId, "source": source.rawValue]
        )
    }

    static func movieHidden(tmdbId: Int) {
        PostHogSDK.shared.capture(
            EventName.movieHidden,
            properties: ["tmdb_id": tmdbId]
        )
    }

    static func movieInterested(tmdbId: Int) {
        PostHogSDK.shared.capture(
            EventName.movieInterested,
            properties: ["tmdb_id": tmdbId]
        )
    }

    // MARK: - Detail

    static func movieDetailViewed(tmdbId: Int, source: DetailSource) {
        PostHogSDK.shared.capture(
            EventName.movieDetailViewed,
            properties: ["tmdb_id": tmdbId, "source": source.rawValue]
        )
    }

    // MARK: - Reels + trailer

    static func trailerPlayed(videoId: String) {
        PostHogSDK.shared.capture(
            EventName.trailerPlayed,
            properties: ["video_id": videoId]
        )
    }

    static func trailerCompleted(videoId: String) {
        PostHogSDK.shared.capture(
            EventName.trailerCompleted,
            properties: ["video_id": videoId]
        )
    }

    static func reelViewed(
        tmdbId: Int,
        position: Int,
        feed: FeedSource,
        timeOnCardMs: Int
    ) {
        PostHogSDK.shared.capture(
            EventName.reelViewed,
            properties: [
                "tmdb_id": tmdbId,
                "position": position,
                "feed": feed.rawValue,
                "time_on_card_ms": timeOnCardMs,
            ]
        )
    }

    // MARK: - Feed

    static func feedRefreshed(source: FeedSource) {
        PostHogSDK.shared.capture(
            EventName.feedRefreshed,
            properties: ["source": source.rawValue]
        )
    }

    static func feedLoadMore(source: FeedSource, batchNum: Int) {
        PostHogSDK.shared.capture(
            EventName.feedLoadMore,
            properties: ["source": source.rawValue, "batch_num": batchNum]
        )
    }

    // MARK: - Search

    static func searchPerformed(queryLength: Int, resultCount: Int) {
        PostHogSDK.shared.capture(
            EventName.searchPerformed,
            properties: [
                "query_length": queryLength,
                "result_count": resultCount,
                "zero_results": resultCount == 0,
            ]
        )
    }

    static func aiSearchPerformed(
        queryLength: Int,
        resultCount: Int,
        isPremium: Bool,
        hitRateLimit: Bool
    ) {
        PostHogSDK.shared.capture(
            EventName.aiSearchPerformed,
            properties: [
                "query_length": queryLength,
                "result_count": resultCount,
                "is_premium": isPremium,
                "hit_rate_limit": hitRateLimit,
            ]
        )
    }

    // MARK: - Paywall + subscription

    static func paywallShown(source: PaywallSource) {
        PostHogSDK.shared.capture(
            EventName.paywallShown,
            properties: ["source": source.rawValue]
        )
    }

    static func paywallDismissed(source: PaywallSource) {
        PostHogSDK.shared.capture(
            EventName.paywallDismissed,
            properties: ["source": source.rawValue]
        )
    }

    static func subscriptionStarted(productId: String) {
        PostHogSDK.shared.capture(
            EventName.subscriptionStarted,
            properties: ["product_id": productId]
        )
    }

    static func subscriptionRestored() {
        PostHogSDK.shared.capture(EventName.subscriptionRestored)
    }

    // MARK: - Social

    static func friendRequestSent() {
        PostHogSDK.shared.capture(EventName.friendRequestSent)
    }

    static func friendRequestAccepted() {
        PostHogSDK.shared.capture(EventName.friendRequestAccepted)
    }

    static func friendRequestRejected() {
        PostHogSDK.shared.capture(EventName.friendRequestRejected)
    }

    static func groupCreated() {
        PostHogSDK.shared.capture(EventName.groupCreated)
    }

    static func groupJoined() {
        PostHogSDK.shared.capture(EventName.groupJoined)
    }

    static func groupLeft() {
        PostHogSDK.shared.capture(EventName.groupLeft)
    }

    // MARK: - Navigation

    static func tabSwitched(tab: String) {
        PostHogSDK.shared.capture(
            EventName.tabSwitched,
            properties: ["tab": tab]
        )
    }

    // MARK: - Notifications

    static func pushNotificationTapped(type: PushType) {
        PostHogSDK.shared.capture(
            EventName.pushNotificationTapped,
            properties: ["type": type.rawValue]
        )
    }

    // MARK: - Onboarding + tutorial

    static func onboardingStarted() {
        PostHogSDK.shared.capture(EventName.onboardingStarted)
    }

    static func onboardingStepViewed(step: OnboardingStep) {
        PostHogSDK.shared.capture(
            EventName.onboardingStepViewed,
            properties: ["step": step.rawValue]
        )
    }

    static func onboardingCompleted() {
        PostHogSDK.shared.capture(EventName.onboardingCompleted)
    }

    static func onboardingDropped(step: OnboardingStep) {
        PostHogSDK.shared.capture(
            EventName.onboardingDropped,
            properties: ["step": step.rawValue]
        )
    }

    static func tutorialCompleted(tutorial: TutorialName) {
        PostHogSDK.shared.capture(
            EventName.tutorialCompleted,
            properties: ["tutorial": tutorial.rawValue]
        )
    }

    static func tutorialSkipped(tutorial: TutorialName, step: Int) {
        PostHogSDK.shared.capture(
            EventName.tutorialSkipped,
            properties: ["tutorial": tutorial.rawValue, "step": step]
        )
    }

    /// Raw error detail for debugging. Callers must not put this string on screen.
    static func errorShown(screen: String, category: String, detail: String) {
        PostHogSDK.shared.capture(
            EventName.errorShown,
            properties: [
                "screen": screen,
                "category": category,
                "detail": detail,
            ]
        )
    }
}

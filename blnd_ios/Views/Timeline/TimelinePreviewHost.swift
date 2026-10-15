#if DEBUG
import SwiftUI

/// Launch with `-TimelinePreview` and `-TimelineScreen diary|blend|log`.
/// Used to screenshot the diary when the timeline endpoints are not on the server.
enum TimelinePreview {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-TimelinePreview")
    }

    enum Screen: String {
        case diary, blend, log
    }

    static var screen: Screen {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-TimelineScreen"),
              args.indices.contains(index + 1),
              let screen = Screen(rawValue: args[index + 1])
        else { return .diary }
        return screen
    }
}

struct TimelinePreviewHost: View {
    var body: some View {
        switch TimelinePreview.screen {
        case .diary:
            diaryScreen
        case .blend:
            blendScreen
        case .log:
            logScreen
        }
    }

    private var diaryScreen: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Circle()
                        .fill(AppTheme.avatarGradient)
                        .frame(width: 72, height: 72)
                        .padding(.top, 24)
                        .padding(.bottom, 12)
                    Text("Jonathan")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Text("@jonathan")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.bottom, 20)

                    Text("Diary")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                        .overlay(alignment: .bottomLeading) {
                            Rectangle()
                                .fill(.white)
                                .frame(width: 36, height: 2)
                                .padding(.leading, 24)
                        }

                    WatchTimelineScreen(
                        source: .preview(TimelinePreviewData.diary),
                        embedsInParentScroll: true,
                        emptyTitle: "Your diary is empty",
                        emptyMessage: "Rate a movie and tag the friends you watched it with."
                    )
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var blendScreen: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("Friday Blend")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Maya, Chris, Alex")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(.top, 16)
                .padding(.bottom, 12)

                Text("Timeline")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                Divider().overlay(AppTheme.border)

                WatchTimelineScreen(
                    source: .preview(TimelinePreviewData.blend),
                    showsViewer: true,
                    emptyTitle: "No shared history yet",
                    emptyMessage: "Movies this blend watches will land here."
                )
            }
            .background(AppTheme.background)
            .navigationTitle("Blend")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var logScreen: some View {
        ScrollView {
            RateMovieSheet(
                title: "Paper Cities",
                year: "2024",
                tmdbId: 4242,
                existingRating: 4.5,
                previewFriends: TimelinePreviewData.friends,
                previewSelection: ["alex", "sam"]
            )
        }
        .background(AppTheme.card)
    }
}

enum TimelinePreviewData {
    static let alex = WatchCompanion(userId: "alex", username: "alex", displayName: "Alex", avatarUrl: nil)
    static let sam = WatchCompanion(userId: "sam", username: "sam", displayName: "Sam", avatarUrl: nil)
    static let jordan = WatchCompanion(userId: "jordan", username: "jordan", displayName: "Jordan", avatarUrl: nil)
    static let maya = WatchCompanion(userId: "maya", username: "maya", displayName: "Maya", avatarUrl: nil)
    static let chris = WatchCompanion(userId: "chris", username: "chris", displayName: "Chris", avatarUrl: nil)

    static let friends: [FriendResponse] = [
        FriendResponse(friendshipId: 1, id: "alex", username: "alex", displayName: "Alex", avatarUrl: nil),
        FriendResponse(friendshipId: 2, id: "sam", username: "sam", displayName: "Sam", avatarUrl: nil),
        FriendResponse(friendshipId: 3, id: "jordan", username: "jordan", displayName: "Jordan", avatarUrl: nil),
    ]

    static let diary: [TimelineEntry] = [
        TimelineEntry(
            id: 1, tmdbId: 101, title: "Paper Cities", year: 2024, rating: 4.5,
            watchedDate: "2026-10-12", watchedWith: [alex, sam]
        ),
        TimelineEntry(
            id: 2, tmdbId: 102, title: "Northern Lights", year: 2022, rating: 5,
            watchedDate: "2026-10-03", watchedWith: [jordan]
        ),
        TimelineEntry(
            id: 3, tmdbId: 103, title: "The Quiet Year", year: 2021, rating: 3.5,
            watchedDate: "2026-09-18", watchedWith: [alex, sam, jordan]
        ),
        TimelineEntry(
            id: 4, tmdbId: 104, title: "Golden Hour", year: 2019, rating: 4,
            watchedDate: "2026-09-02"
        ),
    ]

    static let blend: [TimelineEntry] = [
        TimelineEntry(
            id: 11, tmdbId: 201, title: "Velvet Storm", year: 2023, rating: 4,
            watchedDate: "2026-10-11", watchedWith: [alex, sam], watchedBy: maya
        ),
        TimelineEntry(
            id: 12, tmdbId: 202, title: "Silver Linings", year: 2018, rating: 4.5,
            watchedDate: "2026-10-02", watchedWith: [jordan], watchedBy: chris
        ),
        TimelineEntry(
            id: 13, tmdbId: 203, title: "Lost Frequency", year: 2020, rating: 3,
            watchedDate: "2026-08-22", watchedWith: [sam], watchedBy: alex
        ),
    ]
}
#endif

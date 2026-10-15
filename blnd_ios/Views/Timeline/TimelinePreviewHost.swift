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

    static var liveBase: String? { argument(after: "-TimelineLive") }
    static var liveToken: String? { argument(after: "-TimelineToken") }

    private static func argument(after flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }
}

struct TimelinePreviewHost: View {
    var body: some View {
        switch TimelinePreview.screen {
        case .diary:
            if let base = TimelinePreview.liveBase, let token = TimelinePreview.liveToken {
                TimelineLiveDiary(base: base, token: token)
            } else {
                diaryScreen
            }
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

private struct TimelineLiveDiary: View {
    let base: String
    let token: String
    @State private var entries: [TimelineEntry] = []
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Group {
                if let failure {
                    ErrorStateView(message: failure)
                } else if entries.isEmpty {
                    ProgressView().tint(.white)
                } else {
                    WatchTimelineScreen(
                        source: .preview(entries),
                        embedsInParentScroll: false,
                        emptyTitle: "Your diary is empty",
                        emptyMessage: "Movies you watch will show up here."
                    )
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Diary")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await load() }
    }

    private func load() async {
        var cursor: String?
        var page = 0
        var collected: [TimelineEntry] = []
        do {
            while page < 3 {
                var items = [URLQueryItem(name: "limit", value: "8")]
                if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
                var components = URLComponents(string: base + "/tracking/timeline")
                components?.queryItems = items
                guard let url = components?.url else { throw APIError.invalidURL }
                var request = URLRequest(url: url)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (data, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard (200 ..< 300).contains(status) else {
                    throw APIError.badRequest(APIErrorEnvelope.message(from: data) ?? "Request failed (\(status))")
                }
                let decoded = try JSONDecoder().decode(TimelinePage.self, from: data)
                collected.append(contentsOf: decoded.results)
                cursor = decoded.nextCursor
                page += 1
                if cursor == nil { break }
            }
            entries = collected
        } catch {
            failure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

enum TimelinePreviewData {
    static let alex = TimelinePerson(id: "alex", name: "Alex", avatar: nil)
    static let sam = TimelinePerson(id: "sam", name: "Sam", avatar: nil)
    static let jordan = TimelinePerson(id: "jordan", name: "Jordan", avatar: nil)
    static let maya = TimelinePerson(id: "maya", name: "Maya", avatar: nil)
    static let chris = TimelinePerson(id: "chris", name: "Chris", avatar: nil)
    static let jonathan = TimelinePerson(id: "jonathan", name: "Jonathan", avatar: nil)

    static func media(_ tmdbId: Int, _ title: String, year: Int, type: MediaType = .movie) -> TimelineMedia {
        TimelineMedia(tmdbId: tmdbId, title: title, poster: nil, year: year, mediaType: type)
    }

    static let friends: [FriendResponse] = [
        FriendResponse(friendshipId: 1, id: "alex", username: "alex", displayName: "Alex", avatarUrl: nil),
        FriendResponse(friendshipId: 2, id: "sam", username: "sam", displayName: "Sam", avatarUrl: nil),
        FriendResponse(friendshipId: 3, id: "jordan", username: "jordan", displayName: "Jordan", avatarUrl: nil),
    ]

    static let diary: [TimelineEntry] = [
        TimelineEntry(
            logId: 1,
            createdAt: "2026-10-12T18:04:11.352080Z",
            date: "2026-10-12",
            rating: 4.5,
            media: media(101, "Paper Cities", year: 2024),
            user: jonathan,
            watchedWith: [alex, sam]
        ),
        TimelineEntry(
            logId: 2,
            createdAt: "2026-10-03T02:00:00.000000Z",
            date: "2026-10-03",
            rating: 5,
            media: media(102, "Northern Lights", year: 2022, type: .tv),
            user: jonathan,
            watchedWith: [jordan]
        ),
        TimelineEntry(
            logId: 3,
            date: "2026-09-18",
            rating: 3.5,
            media: media(103, "The Quiet Year", year: 2021),
            user: jonathan,
            watchedWith: [alex, sam, jordan]
        ),
        TimelineEntry(
            logId: 4,
            date: "2026-09-02",
            rating: 4,
            media: media(104, "Golden Hour", year: 2019),
            user: jonathan
        ),
    ]

    static let blend: [TimelineEntry] = [
        TimelineEntry(
            logId: 11,
            date: "2026-10-11",
            rating: 4,
            media: media(201, "Velvet Storm", year: 2023),
            user: maya,
            watchedWith: [alex, sam]
        ),
        TimelineEntry(
            logId: 12,
            date: "2026-10-02",
            rating: 4.5,
            media: media(202, "Silver Linings", year: 2018, type: .tv),
            user: chris,
            watchedWith: [jordan]
        ),
        TimelineEntry(
            logId: 13,
            date: "2026-08-22",
            rating: 3,
            media: media(203, "Lost Frequency", year: 2020),
            user: alex,
            watchedWith: [sam]
        ),
    ]
}
#endif

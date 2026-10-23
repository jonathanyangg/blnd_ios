import SwiftUI

enum SearchSegment: String, CaseIterable, Identifiable {
    case all = "All"
    case movies = "Movies"
    case shows = "TV"
    case people = "People"
    case users = "Users"
    case blends = "Blends"
    case assist = "AI"

    var id: String {
        rawValue
    }
}

struct UnifiedSearchResults: View {
    let segment: SearchSegment
    let movies: [MovieResponse]
    let shows: [TVShowResponse]
    let actors: [PersonResult]
    let users: [UserSearchResult]
    let blends: [GroupResponse]
    let query: String
    let isLoading: Bool
    let hasSearched: Bool
    let onSelectActor: (PersonResult) -> Void
    var onSelectResult: () -> Void = {}

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var visibleBlends: [GroupResponse] {
        guard !trimmedQuery.isEmpty else { return [] }
        return blends.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var showsMovies: Bool {
        segment == .all || segment == .movies
    }

    private var showsTV: Bool {
        segment == .all || segment == .shows
    }

    private var showsPeople: Bool {
        segment == .all || segment == .people
    }

    private var showsUsers: Bool {
        segment == .all || segment == .users
    }

    private var showsBlends: Bool {
        segment == .all || segment == .blends
    }

    var body: some View {
        if segment == .assist {
            EmptyView()
        } else if isLoading, movies.isEmpty, actors.isEmpty, users.isEmpty {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if !hasSearched {
            prompt("Search movies, people, users, and blends")
        } else if nothingToShow {
            prompt("No results for \"\(query)\"")
        } else {
            VStack(alignment: .leading, spacing: 22) {
                if showsMovies, !movies.isEmpty || segment == .movies {
                    section("Movies", empty: movies.isEmpty) {
                        ForEach(movies) { movie in
                            NavigationLink {
                                MovieDetailView(
                                    tmdbId: movie.tmdbId,
                                    title: movie.title,
                                    source: .search
                                )
                            } label: {
                                movieRow(movie)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("search.result")
                        }
                    }
                }
                if showsTV, !shows.isEmpty || segment == .shows {
                    section("TV", empty: shows.isEmpty) {
                        ForEach(shows) { show in
                            showRow(show)
                        }
                    }
                }
                if showsPeople, !actors.isEmpty || segment == .people {
                    section("People", empty: actors.isEmpty) {
                        ForEach(actors) { actor in
                            Button { onSelectActor(actor) } label: {
                                actorRow(actor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if showsUsers, !users.isEmpty || segment == .users {
                    section("Users", empty: users.isEmpty) {
                        ForEach(users) { user in
                            NavigationLink {
                                FriendProfileView(friend: FriendResponse(
                                    friendshipId: user.friendshipId,
                                    id: user.id,
                                    username: user.username,
                                    displayName: user.displayName,
                                    avatarUrl: user.avatarUrl
                                ))
                            } label: {
                                userRow(user)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if showsBlends, !visibleBlends.isEmpty || segment == .blends {
                    section("Blends", empty: visibleBlends.isEmpty) {
                        ForEach(visibleBlends) { blend in
                            NavigationLink {
                                GroupDetailView(groupId: blend.id)
                            } label: {
                                blendRow(blend)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
            // Any result tap (movie, show, person, user, blend) counts as using the query.
            .simultaneousGesture(TapGesture().onEnded(onSelectResult))
        }
    }

    private var nothingToShow: Bool {
        let moviesEmpty = !showsMovies || movies.isEmpty
        let showsEmpty = !showsTV || shows.isEmpty
        let peopleEmpty = !showsPeople || actors.isEmpty
        let usersEmpty = !showsUsers || users.isEmpty
        let blendsEmpty = !showsBlends || visibleBlends.isEmpty
        return moviesEmpty && showsEmpty && peopleEmpty && usersEmpty && blendsEmpty
    }

    private func section(
        _ title: String,
        empty: Bool,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
            if empty {
                Text("No \(title.lowercased()) for \"\(query)\"")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textDim)
                    .padding(.horizontal, 24)
            } else {
                content()
            }
        }
    }

    private func prompt(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
            .padding(.horizontal, 24)
    }

    private func showRow(_ show: TVShowResponse) -> some View {
        HStack(spacing: 12) {
            poster(show.posterPath)
            VStack(alignment: .leading, spacing: 2) {
                Text(show.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let year = show.year {
                    Text(String(year))
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func movieRow(_ movie: MovieResponse) -> some View {
        HStack(spacing: 12) {
            poster(movie.posterPath)
            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !movie.yearString.isEmpty {
                    Text(movie.yearString)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func poster(_ path: String?) -> some View {
        let base = "https://image.tmdb.org/t/p/w185"
        return Group {
            if let path, let url = URL(string: base + path) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(AppTheme.card)
                }
            } else {
                Rectangle().fill(AppTheme.card)
            }
        }
        .frame(width: 36, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func actorRow(_ actor: PersonResult) -> some View {
        HStack(spacing: 12) {
            avatar(path: actor.profilePath)
            VStack(alignment: .leading, spacing: 2) {
                Text(actor.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                if let department = actor.knownForDepartment, !department.isEmpty {
                    Text(department)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func userRow(_ user: UserSearchResult) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatarUrl, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? user.username)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("@\(user.username)")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func blendRow(_ blend: GroupResponse) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(blend.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(blend.memberCount) members")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func avatar(path: String?) -> some View {
        let base = "https://image.tmdb.org/t/p/w185"
        return Group {
            if let path, let url = URL(string: base + path) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(AppTheme.card)
                }
            } else {
                Circle().fill(AppTheme.card)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }
}

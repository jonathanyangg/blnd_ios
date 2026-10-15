import SwiftUI

struct PeopleSearchResults: View {
    let actors: [PersonResult]
    let users: [UserSearchResult]
    let isLoading: Bool
    let hasSearched: Bool
    let query: String
    let onSelectActor: (PersonResult) -> Void

    var body: some View {
        if isLoading, actors.isEmpty, users.isEmpty {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if hasSearched, actors.isEmpty, users.isEmpty {
            searchEmpty(title: "No people for \"\(query)\"")
        } else if !hasSearched {
            searchPrompt("Search for actors and people on blnd")
        } else {
            VStack(alignment: .leading, spacing: 20) {
                if !actors.isEmpty {
                    sectionTitle("Actors")
                    ForEach(actors) { actor in
                        Button {
                            onSelectActor(actor)
                        } label: {
                            actorRow(actor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !users.isEmpty {
                    sectionTitle("On blnd")
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
        }
    }

    private func actorRow(_ actor: PersonResult) -> some View {
        HStack(spacing: 12) {
            personPhoto(path: actor.profilePath)
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

    private func personPhoto(path: String?) -> some View {
        let base = "https://image.tmdb.org/t/p/w185"
        return Group {
            if let path, let url = URL(string: "\(base)\(path)") {
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

struct BlendSearchResults: View {
    let blends: [GroupResponse]
    let isLoading: Bool
    let loadFailed: Bool
    let query: String

    private var visible: [GroupResponse] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return blends }
        return blends.filter { blend in
            blendTitle(blend).localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        if isLoading, blends.isEmpty {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if loadFailed, blends.isEmpty {
            searchPrompt("Couldn't load blends")
        } else if visible.isEmpty {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                searchPrompt("No blends yet")
            } else {
                searchEmpty(title: "No blends for \"\(query)\"")
            }
        } else {
            VStack(spacing: 0) {
                ForEach(visible) { blend in
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

    private func blendRow(_ blend: GroupResponse) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(blendTitle(blend))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(blend.memberCount) members")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textDim)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private func blendTitle(_ blend: GroupResponse) -> String {
        let trimmed = blend.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Blend" }
        return trimmed
    }
}

private func searchEmpty(title: String) -> some View {
    VStack(spacing: 8) {
        Text(title)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
        Text("Try a different search term")
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textDim)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 60)
    .padding(.horizontal, 24)
}

private func searchPrompt(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 14))
        .foregroundStyle(AppTheme.textDim)
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
}

private func sectionTitle(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
}

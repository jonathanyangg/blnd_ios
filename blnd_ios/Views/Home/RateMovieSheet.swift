import SwiftUI

struct RateMovieSheet: View {
    let title: String
    let year: String
    let tmdbId: Int
    var posterPath: String?
    var existingRating: Double?
    var previewFriends: [FriendResponse]?
    var previewSelection: Set<String> = []
    var onSaved: ((Double) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Double = 0
    @State private var isSaving = false
    @State private var saveError: UserFacingError?
    @State private var savedRating: Double?
    @State private var friends: [FriendResponse] = []
    @State private var selectedFriendIds: Set<String> = []
    @State private var didEditCompanions = false
    @State private var companionNote: String?
    @State private var isLoadingFriends = false
    @State private var friendsError: String?

    private var isRerating: Bool {
        existingRating != nil || savedRating != nil
    }

    private var selectedCompanions: [TimelinePerson] {
        friends.compactMap { friend in
            guard selectedFriendIds.contains(friend.id) else { return nil }
            let trimmed = friend.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name = trimmed.isEmpty ? friend.username : trimmed
            return TimelinePerson(id: friend.id, name: name, avatar: friend.avatarUrl)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                posterThumbnail
                    .frame(width: 44, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text(year)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                }

                Spacer()
            }
            .padding(.bottom, 20)

            StarRatingInput(rating: $rating)
                .padding(.bottom, 18)

            watchedWithSection
                .padding(.bottom, 16)

            if let saveError {
                InlineError(message: saveError)
                    .padding(.bottom, 8)
            }

            AppButton(
                label: isRerating ? "Update" : "Save",
                isLoading: isSaving,
                isDisabled: rating == 0
            ) {
                Task { await save() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 32)
        .onAppear {
            if savedRating == nil, let existingRating {
                rating = existingRating
                savedRating = existingRating
            }
            if let previewFriends {
                friends = previewFriends
                selectedFriendIds = previewSelection
            }
        }
        .task {
            guard previewFriends == nil else { return }
            await loadFriendsAndTags()
        }
    }

    private var watchedWithSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Watched with")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)

            if isLoadingFriends {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let friendsError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(friendsError)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                    Button("Retry") {
                        Task { await loadFriendsAndTags() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                }
            } else if friends.isEmpty {
                Text("Add a friend first, then you can tag who you watched this with.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(friends) { friend in
                            friendRow(friend)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            if let companionNote {
                Text(companionNote)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
            }

            if let line = DiaryCopy.watchedWithLine(selectedCompanions) {
                Text(line)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }

    private func friendRow(_ friend: FriendResponse) -> some View {
        let isSelected = selectedFriendIds.contains(friend.id)
        let trimmedName = friend.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let label = trimmedName.isEmpty ? friend.username : trimmedName
        return Button {
            let result = DiaryCopy.toggle(friend.id, in: selectedFriendIds)
            selectedFriendIds = result.selected
            companionNote = result.hitCap ? DiaryCopy.companionCapMessage : nil
            if !result.hitCap { didEditCompanions = true }
        } label: {
            HStack(spacing: 10) {
                AvatarView(url: friend.avatarUrl, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                    Text("@\(friend.username)")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textDim)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .white : AppTheme.textDim)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.cardSecondary : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var posterThumbnail: some View {
        if let url = posterPath.flatMap({ URL(string: "https://image.tmdb.org/t/p/w154\($0)") }) {
            CachedAsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
                    .posterBlur()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.posterGradient)
            }
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.posterGradient)
        }
    }

    private func loadFriendsAndTags() async {
        isLoadingFriends = true
        friendsError = nil
        defer { isLoadingFriends = false }

        do {
            friends = try await FriendsAPI.listFriends().friends
        } catch is CancellationError {
            return
        } catch {
            friendsError = "Couldn't load your friends. Try again."
            return
        }

        do {
            let existing = try await TimelineAPI.watchedWith(tmdbId: tmdbId)
            if !didEditCompanions {
                selectedFriendIds = Set(existing.map(\.id))
            }
        } catch {
            return
        }
    }

    private func save() async {
        guard rating > 0 else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let fromWatchlist = UserActionCache.shared.isWatchlisted(tmdbId)
        if savedRating != rating {
            let isUpdate = existingRating != nil || savedRating != nil
            do {
                if isUpdate {
                    _ = try await TrackingAPI.updateRating(tmdbId: tmdbId, rating: rating)
                } else {
                    _ = try await TrackingAPI.trackMovie(tmdbId: tmdbId, rating: rating, review: nil)
                }
                savedRating = rating
                UserActionCache.shared.didRate(tmdbId, rating: rating)
                Analytics.movieRated(
                    tmdbId: tmdbId,
                    rating: rating,
                    source: .sheet,
                    fromWatchlist: fromWatchlist,
                    isUpdate: isUpdate
                )
                onSaved?(rating)
            } catch {
                saveError = UserFacingError.capture(error, screen: "RateMovie")
                return
            }
        }

        guard didEditCompanions else {
            dismiss()
            return
        }

        do {
            try await TimelineAPI.setWatchedWith(
                tmdbId: tmdbId,
                userIds: Array(selectedFriendIds)
            )
            dismiss()
        } catch APIError.notFound {
            saveError = .client(
                .notFound,
                title: "Unavailable",
                message: DiaryCopy.taggingUnavailable
            )
        } catch {
            saveError = UserFacingError.capture(error, screen: "RateMovie")
        }
    }
}

#Preview {
    RateMovieSheet(title: "Oppenheimer", year: "2023", tmdbId: 872_585)
        .background(AppTheme.card)
}

import SwiftUI

struct FriendsWhoWatchedSection: View {
    let friends: [FriendWatchedResponse]
    @State private var showAll = false

    var body: some View {
        if !friends.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Button { showAll = true } label: {
                    HStack(spacing: 4) {
                        Text("Watched by")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textDim)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(friends) { friend in
                            Button { showAll = true } label: {
                                friendTile(friend)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 20)
            .sheet(isPresented: $showAll) {
                AllFriendsWatchedSheet(friends: friends)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(AppTheme.background)
            }
        }
    }

    private func friendTile(
        _ friend: FriendWatchedResponse
    ) -> some View {
        VStack(spacing: 3) {
            AvatarView(url: friend.avatarUrl, size: 36)
            Text(friend.displayName ?? friend.username)
                .font(.system(size: 9))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 36)
            if let rating = friend.rating {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 7))
                    Text(
                        rating.truncatingRemainder(dividingBy: 1) == 0
                            ? String(format: "%.0f", rating)
                            : String(format: "%.1f", rating)
                    )
                    .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.black.opacity(0.7))
                .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Friend Row

struct FriendWatchedRow: View {
    let friend: FriendWatchedResponse

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(url: friend.avatarUrl, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName ?? friend.username)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                if let rating = friend.rating {
                    StarRatingDisplay(rating: rating, starSize: 11)
                }
            }
            Spacer()
        }
    }
}

// MARK: - All Friends Sheet

private struct AllFriendsWatchedSheet: View {
    let friends: [FriendWatchedResponse]
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [FriendWatchedResponse] {
        guard !searchText.isEmpty else { return friends }
        let query = searchText.lowercased()
        return friends.filter {
            $0.username.lowercased().contains(query)
                || ($0.displayName?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if filtered.isEmpty {
                    Spacer()
                    Text("No friends found")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filtered) { friend in
                                FriendWatchedRow(friend: friend)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Watched by")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textDim)
            TextField("Search friends", text: $searchText)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(10)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

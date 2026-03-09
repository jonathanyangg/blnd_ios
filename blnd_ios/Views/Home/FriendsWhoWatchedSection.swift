import SwiftUI

struct FriendsWhoWatchedSection: View {
    let friends: [FriendWatchedResponse]
    @State private var showAll = false

    private let previewLimit = 5

    var body: some View {
        if !friends.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Friends who watched")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                ForEach(friends.prefix(previewLimit)) { friend in
                    FriendWatchedRow(friend: friend)
                }

                if friends.count > previewLimit {
                    Button {
                        showAll = true
                    } label: {
                        Text("View all \(friends.count) friends")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.bottom, 20)
            .sheet(isPresented: $showAll) {
                AllFriendsWatchedSheet(friends: friends)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(AppTheme.background)
            }
        }
    }
}

// MARK: - Friend Row

struct FriendWatchedRow: View {
    let friend: FriendWatchedResponse

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(size: 32)
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
            .navigationTitle("Friends who watched")
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

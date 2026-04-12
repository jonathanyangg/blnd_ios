import SwiftUI

// MARK: - FriendsListSheet

struct FriendsListSheet: View {
    let friends: [PublicFriendResponse]
    let isLoading: Bool
    let onSelectFriend: (PublicFriendResponse) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 40)
                } else if friends.isEmpty {
                    Text("No friends yet")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(friends) { friend in
                            Button {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onSelectFriend(friend)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(url: friend.avatarUrl)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(friend.displayName ?? friend.username)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.white)
                                        Text("@\(friend.username)")
                                            .font(.system(size: 13))
                                            .foregroundStyle(AppTheme.textMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.textDim)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 24)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(AppTheme.cardSecondary)
                                .padding(.horizontal, 24)
                        }
                    }
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - MutualsListSheet

struct MutualsListSheet: View {
    let mutuals: [MutualFriendResponse]
    let onSelectFriend: (PublicFriendResponse) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if mutuals.isEmpty {
                    Text("No mutual friends")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(mutuals) { mutual in
                            Button {
                                dismiss()
                                let asFriend = PublicFriendResponse(
                                    id: mutual.id,
                                    username: mutual.username,
                                    displayName: mutual.displayName,
                                    avatarUrl: mutual.avatarUrl
                                )
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onSelectFriend(asFriend)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(url: mutual.avatarUrl)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mutual.displayName ?? mutual.username)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.white)
                                        Text("@\(mutual.username)")
                                            .font(.system(size: 13))
                                            .foregroundStyle(AppTheme.textMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.textDim)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 24)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(AppTheme.cardSecondary)
                                .padding(.horizontal, 24)
                        }
                    }
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Mutual Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

import SwiftUI

struct FriendProfileView: View {
    let friend: FriendResponse

    @State private var showRemoveAlert = false
    @State private var isRemoving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile header
                VStack(spacing: 0) {
                    AvatarView(size: 80)
                        .padding(.bottom, 12)

                    Text(friend.displayName ?? friend.username)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Text("@\(friend.username)")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.bottom, 16)
                }
                .padding(.top, 20)
                .padding(.bottom, 24)

                // Remove friend button
                Button {
                    showRemoveAlert = true
                } label: {
                    HStack(spacing: 6) {
                        if isRemoving {
                            ProgressView()
                                .tint(AppTheme.textMuted)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "person.badge.minus")
                                .font(.system(size: 14))
                        }
                        Text("Remove Friend")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.card)
                    .clipShape(Capsule())
                }
                .disabled(isRemoving)
                .padding(.bottom, 32)
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .alert("Remove Friend", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task { await removeFriend() }
            }
        } message: {
            Text(
                "Remove @\(friend.username) from your friends?"
            )
        }
    }

    private func removeFriend() async {
        guard let friendshipId = friend.friendshipId else { return }
        isRemoving = true
        do {
            try await FriendsAPI.removeFriend(friendshipId: friendshipId)
            dismiss()
        } catch {
            print("[FriendProfileView] Remove failed: \(error)")
        }
        isRemoving = false
    }
}

#Preview {
    NavigationStack {
        FriendProfileView(
            friend: FriendResponse(
                friendshipId: 1,
                id: "abc",
                username: "maria",
                displayName: "Maria K.",
                avatarUrl: nil
            )
        )
    }
}

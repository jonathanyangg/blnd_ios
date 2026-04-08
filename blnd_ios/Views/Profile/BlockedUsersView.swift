import SwiftUI

struct BlockedUsersView: View {
    @State private var blocked: [BlockedUserResponse] = []
    @State private var isLoading = true
    @State private var unblockingId: String?
    @State private var pendingUnblock: BlockedUserResponse?

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 60)
            } else if blocked.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(blocked) { user in
                        blockedRow(user)
                        Divider()
                            .background(AppTheme.cardSecondary)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 8)
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .swipeBackGesture()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .principal) {
                Text("Blocked Users")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .alert(
            pendingUnblock.map { "Unblock @\($0.username)?" } ?? "",
            isPresented: Binding(
                get: { pendingUnblock != nil },
                set: { if !$0 { pendingUnblock = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Unblock") {
                if let user = pendingUnblock {
                    Task { await unblock(user) }
                }
            }
        } message: {
            Text("They'll be able to find you and send friend requests again.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.raised")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.textDim)
            Text("No blocked users")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text("Users you block will appear here")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
        }
        .padding(.top, 80)
    }

    private func blockedRow(_ user: BlockedUserResponse) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatarUrl)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? user.username)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                Text("@\(user.username)")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            if unblockingId == user.id {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
            } else {
                Button {
                    pendingUnblock = user
                } label: {
                    Text("Unblock")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.cardSecondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 24)
    }

    private func load() async {
        do {
            let response = try await FriendsAPI.listBlockedUsers()
            blocked = response.blocked
        } catch { /* Non-critical — empty list shown */ }
        isLoading = false
    }

    private func unblock(_ user: BlockedUserResponse) async {
        unblockingId = user.id
        do {
            try await FriendsAPI.unblockUser(userId: user.id)
            blocked.removeAll { $0.id == user.id }
        } catch { /* Non-critical — user can retry */ }
        unblockingId = nil
        pendingUnblock = nil
    }
}

#Preview {
    NavigationStack {
        BlockedUsersView()
    }
}

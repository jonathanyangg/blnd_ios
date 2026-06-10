import SwiftUI

/// Scrollable modal listing everyone who's watched a movie and their rating.
struct WatchedBySheet: View {
    let friends: [FriendWatchedResponse]
    let onSelectFriend: (FriendResponse) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(friends) { friend in
                        Button {
                            onSelectFriend(friend.asFriendResponse)
                        } label: {
                            row(friend)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(AppTheme.card)
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

    private func row(_ friend: FriendWatchedResponse) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: friend.avatarUrl, size: 40)

            Text(friend.displayName ?? friend.username)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            if let rating = friend.rating {
                let text = rating.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", rating)
                    : String(format: "%.1f", rating)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.system(size: 11))
                    Text(text).font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

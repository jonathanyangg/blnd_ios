import SwiftUI

struct ActivityFeedView: View {
    @State private var items: [InboxItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 60)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                    Button("Retry") {
                        Task { await loadInbox() }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                }
                .padding(.top, 60)
            } else if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.textDim)
                    Text("No notifications yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Activity from friends and blends will show up here")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        inboxRow(item)

                        Divider()
                            .background(AppTheme.cardSecondary)
                            .padding(.horizontal, 24)
                    }
                }
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
                Text("Notifications")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .task {
            await loadInbox()
            // Mark all as read when viewing
            try? await NotificationAPI.markInboxRead()
        }
        .refreshable { await loadInbox() }
    }

    // MARK: - Inbox Row

    private func inboxRow(_ item: InboxItem) -> some View {
        HStack(spacing: 12) {
            // Avatar or icon
            if let avatarUrl = item.fromAvatarUrl {
                AvatarView(url: avatarUrl, size: 40)
            } else {
                Image(systemName: item.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.cardSecondary)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.body)
                    .font(.system(size: 14))
                    .foregroundStyle(item.read ? AppTheme.textMuted : .white)
                    .lineLimit(2)

                Text(item.timeAgo)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textDim)
            }

            Spacer()

            if !item.read {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Data

    private func loadInbox() async {
        do {
            let response = try await NotificationAPI.getInbox()
            items = response.results
        } catch {
            if items.isEmpty {
                errorMessage = "Could not load notifications"
            }
        }
        isLoading = false
    }
}

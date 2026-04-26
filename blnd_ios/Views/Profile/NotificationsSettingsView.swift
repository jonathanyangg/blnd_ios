import SwiftUI

struct NotificationsSettingsView: View {
    @State private var friendRequests = true
    @State private var groupInvites = true
    @State private var recommendations = true
    @State private var friendActivity = true
    @State private var commentReplies = true
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error {
                    errorSection(error)
                } else {
                    preferencesSection
                    systemSettingsHint
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
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
            await loadPreferences()
        }
    }

    // MARK: - Sections

    private var preferencesSection: some View {
        VStack(spacing: 0) {
            toggleRow(
                label: "Friend Requests",
                subtitle: "When someone sends you a friend request",
                isOn: $friendRequests
            ) {
                await updatePreference(friendRequests: friendRequests)
            }
            Divider().background(AppTheme.cardSecondary)
            toggleRow(
                label: "Blend Invites",
                subtitle: "When someone adds you to a blend",
                isOn: $groupInvites
            ) {
                await updatePreference(groupInvites: groupInvites)
            }
            Divider().background(AppTheme.cardSecondary)
            toggleRow(
                label: "Recommendations",
                subtitle: "Weekly digest of new recommendations",
                isOn: $recommendations
            ) {
                await updatePreference(recommendations: recommendations)
            }
            Divider().background(AppTheme.cardSecondary)
            toggleRow(
                label: "Friend Activity",
                subtitle: "When a friend rates a movie 4+ stars",
                isOn: $friendActivity
            ) {
                await updatePreference(friendActivity: friendActivity)
            }
            Divider().background(AppTheme.cardSecondary)
            toggleRow(
                label: "Comment Replies",
                subtitle: "When someone replies to your comment",
                isOn: $commentReplies
            ) {
                await updatePreference(commentReplies: commentReplies)
            }
        }
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }

    private var systemSettingsHint: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gear")
                    .font(.system(size: 13))
                Text("System Notification Settings")
                    .font(.system(size: 13))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(AppTheme.textMuted)
            .padding(16)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
        }
    }

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await loadPreferences() }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Toggle Row

    private func toggleRow(
        label: String,
        subtitle: String,
        isOn: Binding<Bool>,
        onChange: @escaping () async -> Void
    ) -> some View {
        Toggle(isOn: Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                isOn.wrappedValue = newValue
                Task { await onChange() }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textDim)
            }
        }
        .tint(.green)
        .padding(16)
    }

    // MARK: - API

    private func loadPreferences() async {
        isLoading = true
        error = nil
        do {
            let prefs = try await NotificationAPI.getPreferences()
            friendRequests = prefs.friendRequests
            groupInvites = prefs.groupInvites
            recommendations = prefs.recommendations
            friendActivity = prefs.friendActivity
            commentReplies = prefs.commentReplies
            isLoading = false
        } catch {
            self.error = "Could not load notification preferences."
            isLoading = false
        }
    }

    // swiftlint:disable discouraged_optional_boolean
    private func updatePreference(
        friendRequests: Bool? = nil,
        groupInvites: Bool? = nil,
        recommendations: Bool? = nil,
        friendActivity: Bool? = nil,
        commentReplies: Bool? = nil
    ) async {
        // swiftlint:enable discouraged_optional_boolean
        let request = UpdatePreferencesRequest(
            friendRequests: friendRequests,
            groupInvites: groupInvites,
            recommendations: recommendations,
            friendActivity: friendActivity,
            commentReplies: commentReplies
        )
        do {
            let prefs = try await NotificationAPI.updatePreferences(request)
            self.friendRequests = prefs.friendRequests
            self.groupInvites = prefs.groupInvites
            self.recommendations = prefs.recommendations
            self.friendActivity = prefs.friendActivity
            self.commentReplies = prefs.commentReplies
        } catch {
            // Revert toggle on failure by reloading
            await loadPreferences()
        }
    }
}

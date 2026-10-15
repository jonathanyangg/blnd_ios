import SwiftUI

struct NotificationsSettingsView: View {
    private let isPreview: Bool
    @State private var prefs: NotificationPrivacyPrefs
    @State private var loadError: String?
    @State private var saveError: String?

    init(preview: NotificationPrivacyPrefs? = nil) {
        isPreview = preview != nil
        _prefs = State(initialValue: preview ?? NotificationPrefsStore.load())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let loadError { note(loadError) }
                if let saveError { note(saveError) }
                sharingCard
                channelSection(
                    "Friends' ratings",
                    inApp: \.friendRatings,
                    push: \.friendRatings
                )
                channelSection(
                    "Blend activity",
                    inApp: \.blendActivity,
                    push: \.blendActivity
                )
                channelSection(
                    "Comments and likes",
                    inApp: \.commentsLikes,
                    push: \.commentsLikes
                )
                channelSection(
                    "Watched-with tags",
                    inApp: \.watchedWith,
                    push: \.watchedWith
                )
                channelSection(
                    "Recommendations",
                    inApp: \.recommendations,
                    push: \.recommendations
                )
                systemSettings
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .swipeBackGesture()
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { BackButton() }
            ToolbarItem(placement: .principal) {
                Text("Notifications & Privacy")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .task { await load() }
        .accessibilityIdentifier("notifications-privacy")
    }

    private var sharingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share my ratings in friends' notifications")
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Picker("Share my ratings", selection: shareBinding) {
                ForEach(ShareAudience.allCases, id: \.self) { audience in
                    Text(audience.label).tag(audience)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }

    private var shareBinding: Binding<ShareAudience> {
        Binding(
            get: { prefs.shareRatings },
            set: { audience in
                Task { await update { $0.shareRatings = audience } }
            }
        )
    }

    private func channelSection(
        _ title: String,
        inApp: WritableKeyPath<ChannelPrefs, Bool>,
        push: WritableKeyPath<ChannelPrefs, Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                toggle(
                    "In-app",
                    subtitle: "Show in your notification center",
                    isOn: prefs.inApp[keyPath: inApp]
                ) { value in
                    await update { $0.inApp[keyPath: inApp] = value }
                }
                Divider().background(AppTheme.cardSecondary)
                toggle("Push", subtitle: "Alert on this phone", isOn: prefs.push[keyPath: push]) { value in
                    await update { $0.push[keyPath: push] = value }
                }
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
        }
    }

    private func toggle(
        _ title: String,
        subtitle: String,
        isOn: Bool,
        set: @escaping (Bool) async -> Void
    ) -> some View {
        Toggle(isOn: Binding(
            get: { isOn },
            set: { value in Task { await set(value) } }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
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

    private var systemSettings: some View {
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

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func load() async {
        guard !isPreview else { return }
        do {
            let server = try await NotificationAPI.getPreferences()
            guard !Task.isCancelled else { return }
            prefs = prefs.applying(server: server)
            NotificationPrefsStore.save(prefs)
            loadError = nil
        } catch {
            guard !Task.isCancelled else { return }
            loadError = FriendlyCopy.refreshSettings
        }
    }

    private func update(_ change: (inout NotificationPrivacyPrefs) -> Void) async {
        let previous = prefs
        var next = prefs
        change(&next)
        prefs = next
        NotificationPrefsStore.save(prefs)
        guard !isPreview else { return }
        do {
            let server = try await NotificationAPI.updatePreferences(prefs.asRequest())
            guard !Task.isCancelled else { return }
            prefs = prefs.applying(server: server)
            NotificationPrefsStore.save(prefs)
            saveError = nil
        } catch {
            guard !Task.isCancelled else { return }
            prefs = previous
            NotificationPrefsStore.save(previous)
            saveError = FriendlyCopy.saveSettings
        }
    }
}

import SwiftUI

private enum SettingsDestination: Hashable {
    case account, notifications, about
}

struct SettingsView: View {
    @Environment(AuthState.self) var authState
    @State private var destination: SettingsDestination?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        settingsRow("Account", icon: "person") {
                            destination = .account
                        }
                        Divider().background(AppTheme.cardSecondary)
                        settingsRow("Notifications", icon: "bell") {
                            destination = .notifications
                        }
                        Divider().background(AppTheme.cardSecondary)
                        settingsRow("Support", icon: "questionmark.circle") {
                            if let url = URL(string: "https://www.blnd.movie/support") {
                                UIApplication.shared.open(url)
                            }
                        }
                        Divider().background(AppTheme.cardSecondary)
                        settingsRow("About", icon: "info.circle") {
                            destination = .about
                        }
                    }
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))

                    Button { authState.logout() } label: {
                        Text("Log Out")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.destructive)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
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
                Text("Settings")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .navigationDestination(item: $destination) { dest in
            switch dest {
            case .account:
                AccountSettingsView()
            case .notifications:
                NotificationsSettingsView()
            case .about:
                AboutSettingsView()
            }
        }
    }

    private func settingsRow(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textDim)
            }
            .padding(16)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AuthState())
    }
}

import RevenueCat
import SwiftUI

private enum SettingsDestination: Hashable {
    case account, notifications, blocked, about, howItWorks
}

struct SettingsView: View {
    @Environment(AuthState.self) var authState
    @State private var destination: SettingsDestination?
    @State private var showPaywall = false
    @State private var isRestoring = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Premium section
                    VStack(spacing: 0) {
                        if authState.isPremium {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(AppTheme.premiumGradient)
                                    .frame(width: 20)
                                BlndPlusBadge(size: 14)
                                Spacer()
                                Text("Active")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.textMuted)
                            }
                            .padding(16)
                        } else {
                            Button { showPaywall = true } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 15))
                                        .foregroundStyle(AppTheme.premiumGradient)
                                        .frame(width: 20)
                                    BlndPlusBadge(size: 14)
                                    Spacer()
                                    Text("Upgrade")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.premiumGradient)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.textDim)
                                }
                                .padding(16)
                            }
                        }
                        Divider().background(AppTheme.cardSecondary)
                        settingsRow("Restore Purchases", icon: "arrow.clockwise") {
                            Task {
                                isRestoring = true
                                _ = try? await Purchases.shared.restorePurchases()
                                await authState.fetchCurrentUser()
                                isRestoring = false
                            }
                        }
                        Divider().background(AppTheme.cardSecondary)
                        settingsRow("Manage Subscription", icon: "creditcard") {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))

                    VStack(spacing: 0) {
                        settingsRow("How It Works", icon: "lightbulb") {
                            destination = .howItWorks
                        }
                    }
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))

                    VStack(spacing: 0) {
                        settingsRow("Account", icon: "person") {
                            destination = .account
                        }
                        Divider().background(AppTheme.cardSecondary)
                        settingsRow("Notifications", icon: "bell") {
                            destination = .notifications
                        }
                        Divider().background(AppTheme.cardSecondary)
                        settingsRow("Blocked Users", icon: "hand.raised") {
                            destination = .blocked
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
        .sheet(isPresented: $showPaywall) {
            PaywallView(source: .settings)
                .environment(authState)
        }
        .navigationDestination(item: $destination) { dest in
            switch dest {
            case .account:
                AccountSettingsView()
            case .notifications:
                NotificationsSettingsView()
            case .blocked:
                BlockedUsersView()
            case .about:
                AboutSettingsView()
            case .howItWorks:
                HowItWorksView()
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

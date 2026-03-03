import SwiftUI

struct SettingsView: View {
    @Environment(AuthState.self) var authState
    private let settingsItems = ["Account", "Notifications", "Privacy", "About"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Settings group
                    VStack(spacing: 0) {
                        ForEach(Array(settingsItems.enumerated()), id: \.element) { index, item in
                            Button {} label: {
                                HStack {
                                    Text(item)
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.textDim)
                                }
                                .padding(16)
                            }

                            if index < settingsItems.count - 1 {
                                Divider()
                                    .background(AppTheme.cardSecondary)
                            }
                        }
                    }
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))

                    // Log Out
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
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

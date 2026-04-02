import SwiftUI

struct FindFriendsView: View {
    @Environment(AuthState.self) var authState
    @Environment(OnboardingState.self) var onboardingState
    @Binding var path: NavigationPath

    @State private var isSyncing = false
    @State private var syncedCount: Int?
    @State private var syncFailed = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(step: 5, total: 5)
                .padding(.top, 12)

            Spacer()

            VStack(spacing: 0) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white)
                    .padding(.bottom, 24)

                Text("Find Your Friends")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text("See which of your contacts are already on blnd")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                if let count = syncedCount {
                    Text("\(count) contacts synced!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.green)
                        .padding(.top, 24)
                }

                if syncFailed {
                    Text("Couldn't access contacts. You can try again later in Settings.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 8) {
                if syncedCount == nil {
                    AppButton(label: "Allow Contacts Access", isLoading: isSyncing) {
                        Task { await syncContacts() }
                    }
                }

                AppButton(
                    label: syncedCount != nil ? "Continue" : "Not Now",
                    style: syncedCount != nil ? .primary : .ghost
                ) {
                    finish()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
    }

    private func syncContacts() async {
        isSyncing = true
        let numbers = await ContactsHelper.fetchPhoneNumbers()

        if numbers.isEmpty {
            syncFailed = true
            isSyncing = false
            return
        }

        do {
            try await FriendsAPI.uploadContacts(phoneNumbers: numbers)
            syncedCount = numbers.count
        } catch {
            syncFailed = true
        }

        isSyncing = false
    }

    private func finish() {
        Task {
            onboardingState.reset()
            await authState.fetchCurrentUser()
            authState.phase = .authenticated
        }
    }
}

#Preview {
    NavigationStack {
        FindFriendsView(path: .constant(NavigationPath()))
            .environment(AuthState())
            .environment(OnboardingState())
    }
}

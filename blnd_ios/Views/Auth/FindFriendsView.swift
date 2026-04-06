import PostHog
import SwiftUI

struct FindFriendsView: View {
    @Environment(AuthState.self) var authState
    @Environment(OnboardingState.self) var onboardingState
    @Binding var path: NavigationPath

    @State private var isSyncing = false
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

            AppButton(label: "Continue", isLoading: isSyncing) {
                Task {
                    await syncContacts()
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

        if !numbers.isEmpty {
            do {
                try await FriendsAPI.uploadContacts(phoneNumbers: numbers)
            } catch {
                syncFailed = true
            }
        }

        isSyncing = false
    }

    private func finish() {
        Task {
            onboardingState.reset()
            await authState.fetchCurrentUser()
            authState.phase = .authenticated
            PostHogSDK.shared.capture("onboarding_completed")
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

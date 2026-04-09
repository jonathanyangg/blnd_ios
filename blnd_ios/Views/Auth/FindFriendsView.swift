import PostHog
import SwiftUI

struct FindFriendsView: View {
    @Environment(AuthState.self) var authState
    @Environment(OnboardingState.self) var onboardingState
    @Binding var path: NavigationPath

    @State private var isSyncing = false

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

                Text(
                    "Next, we'll ask permission to access your contacts. "
                        + "Phone numbers will be sent to blnd's server to find "
                        + "friends already on the app. We only store numbers "
                        + "that match existing users."
                )
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 32)
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
                try await FriendsAPI.uploadContacts(
                    phoneNumbers: numbers
                )
            } catch {
                // Non-critical — user can still proceed
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

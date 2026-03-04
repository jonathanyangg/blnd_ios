import SwiftUI

struct OnboardingCompleteView: View {
    @Environment(AuthState.self) var authState
    @Environment(OnboardingState.self) var onboardingState

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(step: 4, total: 4)
                .padding(.top, 12)

            Spacer()

            VStack(spacing: 0) {
                Text("You're all set")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text("Here's what we think you'll love")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.top, 6)
                    .padding(.bottom, 32)

                // Fanned movie posters
                HStack(spacing: -8) {
                    MovieCard(title: "Parasite", year: "2019", width: 90, height: 130)
                        .offset(y: 8)

                    MovieCard(title: "Oppenheimer", year: "2023", width: 100, height: 148, glow: true)
                        .zIndex(1)

                    MovieCard(title: "Mad Max", year: "2015", width: 90, height: 130)
                        .offset(y: 8)
                }
            }

            Spacer()

            AppButton(label: "Let's go") {
                onboardingState.reset()
                authState.isAuthenticated = true
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    NavigationStack {
        OnboardingCompleteView()
            .environment(AuthState())
            .environment(OnboardingState())
    }
}

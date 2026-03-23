import SwiftUI

struct ChooseUsernameView: View {
    @Environment(AuthState.self) var authState
    @Environment(OnboardingState.self) var onboardingState
    @Binding var path: NavigationPath
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        @Bindable var state = onboardingState

        VStack(spacing: 0) {
            OnboardingProgressBar(step: 3, total: 4)
                .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Choose your username")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 40)

                    Text("This is how friends will find you on blnd")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.top, 6)
                        .padding(.bottom, 32)

                    AppTextField(placeholder: "Name", text: $state.name)
                    AppTextField(placeholder: "Username", text: $state.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if let error {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.destructive)
                            .padding(.bottom, 8)
                    }

                    Spacer().frame(height: 20)

                    AppButton(
                        label: "Continue",
                        isLoading: isLoading,
                        isDisabled: state.username.isEmpty
                    ) {
                        Task { await submit() }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
    }

    private func submit() async {
        guard let idToken = onboardingState.appleIdToken,
              let rawNonce = onboardingState.appleRawNonce else { return }

        isLoading = true
        error = nil

        do {
            // Step 1: Exchange Apple token for BLND session
            let oauthResponse = try await AuthAPI.oauth(
                provider: "apple",
                idToken: idToken,
                nonce: rawNonce,
                authorizationCode: onboardingState.appleAuthCode
            )

            // Save tokens to Keychain so completeOnboarding can authenticate
            KeychainManager.save(key: "accessToken", string: oauthResponse.accessToken)
            KeychainManager.save(key: "refreshToken", string: oauthResponse.refreshToken)
            KeychainManager.save(key: "userId", string: oauthResponse.userId)

            // Step 2: Create profile with username + onboarding data
            let ratedMovies = onboardingState.movieRatings.map { tmdbId, liked in
                RatedMovieRequest(tmdbId: tmdbId, rating: liked ? 4.0 : 2.0)
            }
            let genres = Array(onboardingState.selectedGenres)

            _ = try await AuthAPI.completeOnboarding(
                username: onboardingState.username,
                displayName: onboardingState.name.isEmpty ? nil : onboardingState.name,
                favoriteGenres: genres.isEmpty ? nil : genres,
                ratedMovies: ratedMovies.isEmpty ? nil : ratedMovies,
                appleRefreshToken: onboardingState.appleRefreshToken ?? oauthResponse.appleRefreshToken
            )

            // Both calls succeeded — navigate to completion
            authState.phase = .onboardingPending
            path.append(AuthRoute.onboardingComplete)
        } catch {
            isLoading = false
            // Determine which call failed
            if KeychainManager.readString(key: "accessToken") == nil {
                // OAuth call failed — clear Apple state, user must re-do Apple auth
                onboardingState.appleIdToken = nil
                onboardingState.appleRawNonce = nil
                onboardingState.appleDisplayName = nil
                onboardingState.appleAuthCode = nil
                self.error = error.localizedDescription
            } else {
                // completeOnboarding failed (e.g. username taken) — keep Apple state
                self.error = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChooseUsernameView(path: .constant(NavigationPath()))
            .environment(AuthState())
            .environment(OnboardingState())
    }
}

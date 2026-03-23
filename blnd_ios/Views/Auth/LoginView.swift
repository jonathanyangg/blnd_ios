import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(AuthState.self) var authState
    @Environment(OnboardingState.self) var onboardingState
    @Binding var path: NavigationPath
    @State private var email = ""
    @State private var password = ""
    @State private var appleNonce = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Sign in")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 40)
                        .padding(.bottom, 32)

                    // MARK: - Apple Sign In

                    SignInWithAppleButton(.signIn) { request in
                        let nonce = AppleSignInHelper.randomNonceString()
                        appleNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = AppleSignInHelper.sha256(nonce)
                    } onCompletion: { result in
                        switch result {
                        case let .success(authorization):
                            handleAppleSignIn(authorization)
                        case let .failure(error):
                            let isCancelled = (error as? ASAuthorizationError)?.code == .canceled
                            if !isCancelled {
                                authState.error = error.localizedDescription
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))

                    // MARK: - Divider

                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(AppTheme.border)
                            .frame(height: 1)
                        Text("or")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textMuted)
                        Rectangle()
                            .fill(AppTheme.border)
                            .frame(height: 1)
                    }
                    .padding(.vertical, 20)

                    // MARK: - Email Form

                    AppTextField(placeholder: "Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    AppTextField(placeholder: "Password", text: $password, isSecure: true)

                    if let error = authState.error {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.destructive)
                            .padding(.bottom, 8)
                    }

                    Spacer().frame(height: 20)

                    AppButton(label: "Sign In", isLoading: authState.isLoading) {
                        Task {
                            onboardingState.reset()
                            await authState.login(email: email, password: password)
                        }
                    }

                    Button {
                        // Pop to root, then push sign up
                        path.removeLast(path.count)
                        path.append(AuthRoute.pickGenres)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundStyle(AppTheme.textMuted)
                            Text("Create one")
                                .foregroundStyle(.white)
                        }
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
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

    private func handleAppleSignIn(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else { return }

        // Clear stale onboarding state before processing
        onboardingState.reset()

        // Authorization code for Phase 16 token revocation
        let authCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }

        // Full name -- only available on FIRST authorization
        let givenName = credential.fullName?.givenName
        let familyName = credential.fullName?.familyName
        let displayName = [givenName, familyName].compactMap { $0 }.joined(separator: " ")

        let nonce = appleNonce

        Task {
            guard let response = await authState.loginWithApple(
                idToken: idToken, nonce: nonce, authorizationCode: authCode
            ) else {
                return // Error already set on authState
            }

            if response.isNewUser {
                // Edge case: new user on LoginView -- route to onboarding
                onboardingState.appleIdToken = idToken
                onboardingState.appleRawNonce = nonce
                onboardingState.appleDisplayName = displayName.isEmpty ? nil : displayName
                onboardingState.appleAuthCode = authCode
                onboardingState.appleRefreshToken = response.appleRefreshToken
                if let name = onboardingState.appleDisplayName {
                    onboardingState.name = name
                }
                path.append(AuthRoute.chooseUsername)
            }
            // Returning user: loginWithApple already set .authenticated
        }
    }
}

// MARK: - Reusable back button for navigation

struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .foregroundStyle(.white)
                .font(.system(size: 16, weight: .medium))
        }
    }
}

#Preview {
    NavigationStack {
        LoginView(path: .constant(NavigationPath()))
            .environment(AuthState())
            .environment(OnboardingState())
    }
}

import SwiftUI

struct SignUpView: View {
    @Environment(AuthState.self) var authState
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var navigateToGenres = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(step: 1, total: 4)
                .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Create account")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 40)
                        .padding(.bottom, 32)

                    AppTextField(placeholder: "Name", text: $name)
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

                    AppButton(
                        label: "Continue",
                        isLoading: authState.isLoading,
                        isDisabled: name.isEmpty || email.isEmpty || password.isEmpty
                    ) {
                        Task {
                            await authState.signup(
                                email: email,
                                password: password,
                                username: email.components(separatedBy: "@").first ?? email,
                                displayName: name
                            )
                            if authState.error == nil {
                                navigateToGenres = true
                            }
                        }
                    }

                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(AppTheme.textMuted)
                        // Would pop back to WelcomeView and navigate to Login
                        Text("Sign in")
                            .foregroundStyle(.white)
                    }
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $navigateToGenres) {
            PickGenresView()
        }
    }
}

// MARK: - Styled Text Field

struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text, prompt: promptText)
            } else {
                TextField("", text: $text, prompt: promptText)
            }
        }
        .font(.system(size: 15))
        .foregroundStyle(.white)
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        .padding(.bottom, 12)
    }

    private var promptText: Text {
        Text(placeholder)
            .foregroundStyle(AppTheme.textMuted)
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environment(AuthState())
    }
}

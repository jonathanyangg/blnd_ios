import SwiftUI

struct SignUpView: View {
    @Environment(AuthState.self) var authState
    @Environment(OnboardingState.self) var onboardingState
    @Binding var path: NavigationPath
    @State private var emailError: String?

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(step: 3, total: 4)
                .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Create account")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 40)
                        .padding(.bottom, 32)

                    @Bindable var state = onboardingState

                    AppTextField(placeholder: "Name", text: $state.name)
                    AppTextField(placeholder: "Username", text: $state.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    AppTextField(placeholder: "Email", text: $state.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    AppTextField(placeholder: "Password", text: $state.password, isSecure: true)

                    if !state.password.isEmpty {
                        PasswordRequirements(password: state.password)
                            .padding(.bottom, 8)
                    }

                    if let emailError {
                        Text(emailError)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.destructive)
                            .padding(.bottom, 8)
                    }

                    if let error = authState.error {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.destructive)
                            .padding(.bottom, 8)
                    }

                    Spacer().frame(height: 20)

                    AppButton(
                        label: "Sign Up",
                        isLoading: authState.isLoading,
                        isDisabled: state.name.isEmpty || state.username.isEmpty
                            || state.email.isEmpty || !isValidPassword(state.password)
                    ) {
                        guard isValidEmail(state.email) else {
                            emailError = "Please enter a valid email address"
                            return
                        }
                        emailError = nil
                        Task {
                            await authState.signup(
                                email: state.email,
                                password: state.password,
                                username: state.username,
                                displayName: state.name
                            )
                            if authState.error == nil {
                                path.append(AuthRoute.onboardingComplete)
                            }
                        }
                    }

                    Button {
                        path.removeLast(path.count)
                        path.append(AuthRoute.login)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundStyle(AppTheme.textMuted)
                            Text("Sign in")
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

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private func isValidPassword(_ password: String) -> Bool {
        password.count >= 8 && password.contains(where: \.isUppercase)
    }
}

// MARK: - Password Requirements

private struct PasswordRequirements: View {
    let password: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RequirementRow(
                label: "At least 8 characters",
                isMet: password.count >= 8
            )
            RequirementRow(
                label: "One uppercase letter",
                isMet: password.contains(where: \.isUppercase)
            )
        }
    }
}

private struct RequirementRow: View {
    let label: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundStyle(isMet ? .green : AppTheme.textDim)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(isMet ? AppTheme.textDim : AppTheme.textDim)
        }
    }
}

// MARK: - Styled Text Field

struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @State private var showPassword = false

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if isSecure, !showPassword {
                    SecureField("", text: $text, prompt: promptText)
                } else {
                    TextField("", text: $text, prompt: promptText)
                }
            }
            .font(.system(size: 15))
            .foregroundStyle(.white)

            if isSecure {
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(AppTheme.textMuted)
                        .font(.system(size: 14))
                }
            }
        }
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
        SignUpView(path: .constant(NavigationPath()))
            .environment(AuthState())
            .environment(OnboardingState())
    }
}

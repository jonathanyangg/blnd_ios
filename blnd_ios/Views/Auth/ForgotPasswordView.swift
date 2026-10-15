import SwiftUI

struct ForgotPasswordView: View {
    @Binding var path: NavigationPath
    @State private var email = ""
    @State private var isLoading = false
    @State private var error: UserFacingError?
    @State private var didSend = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Reset password")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 40)
                        .padding(.bottom, 8)

                    Text("Enter your email and we'll send you a link to reset your password.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.bottom, 32)

                    if didSend {
                        // MARK: - Success State

                        VStack(spacing: 16) {
                            Image(systemName: "envelope.badge.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)

                            Text("Check your email")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)

                            Text("We sent a reset link to **\(email)**. It may take a minute to arrive.")
                                .font(.system(size: 15))
                                .foregroundStyle(AppTheme.textMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        // MARK: - Email Form

                        AppTextField(placeholder: "Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)

                        if let error {
                            InlineError(message: error)
                                .padding(.bottom, 8)
                        }

                        Spacer().frame(height: 20)

                        AppButton(
                            label: "Send Reset Link",
                            isLoading: isLoading,
                            isDisabled: email.isEmpty
                        ) {
                            Task { await sendResetLink() }
                        }
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

    private func sendResetLink() async {
        isLoading = true
        error = nil

        do {
            try await AuthAPI.forgotPassword(email: email)
            withAnimation { didSend = true }
        } catch {
            self.error = UserFacingError.capture(error, screen: "ForgotPassword")
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView(path: .constant(NavigationPath()))
    }
}

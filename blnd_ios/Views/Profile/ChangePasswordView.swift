import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorMessage: UserFacingError?
    @State private var showSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                fieldsSection

                if let errorMessage {
                    InlineError(message: errorMessage) {
                        Task { await changePassword() }
                    }
                }

                if !newPassword.isEmpty {
                    PasswordValidation(
                        newPassword: newPassword,
                        confirmPassword: confirmPassword
                    )
                }

                AppButton(
                    label: "Save",
                    isLoading: isSaving,
                    isDisabled: !isFormValid
                ) {
                    Task { await changePassword() }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .swipeBackGesture()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .principal) {
                Text("Change Password")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .alert("Password Changed", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your password has been updated successfully.")
        }
    }

    // MARK: - Fields

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Password")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
                AppTextField(placeholder: "Current password", text: $currentPassword, isSecure: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("New Password")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
                AppTextField(placeholder: "New password", text: $newPassword, isSecure: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Confirm New Password")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
                AppTextField(placeholder: "Confirm new password", text: $confirmPassword, isSecure: true)
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !currentPassword.isEmpty
            && newPassword.count >= 8
            && newPassword.contains(where: \.isUppercase)
            && newPassword == confirmPassword
    }

    // MARK: - Actions

    private func changePassword() async {
        isSaving = true
        errorMessage = nil
        do {
            try await AuthAPI.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            showSuccess = true
        } catch {
            errorMessage = UserFacingError.capture(error, screen: "ChangePassword")
        }
        isSaving = false
    }
}

// MARK: - Password Validation

private struct PasswordValidation: View {
    let newPassword: String
    let confirmPassword: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ValidationRow(
                label: "At least 8 characters",
                isMet: newPassword.count >= 8
            )
            ValidationRow(
                label: "One uppercase letter",
                isMet: newPassword.contains(where: \.isUppercase)
            )
            ValidationRow(
                label: "Passwords match",
                isMet: !confirmPassword.isEmpty && newPassword == confirmPassword
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ValidationRow: View {
    let label: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundStyle(isMet ? .green : AppTheme.textDim)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textDim)
        }
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
    }
}

import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .medium))
                }

                Text("Add Friend")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Username input
            VStack(alignment: .leading, spacing: 12) {
                Text("Enter a username to send a friend request")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)

                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Text("@")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.textDim)
                        TextField("username", text: $username)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(14)
                    .background(AppTheme.card)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: AppTheme.cornerRadiusMedium
                        )
                    )

                    Button {
                        Task { await sendRequest() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.black)
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 15))
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(width: 48, height: 48)
                    .background(
                        username.trimmingCharacters(
                            in: .whitespaces
                        ).isEmpty
                            ? AppTheme.cardSecondary
                            : .white
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: AppTheme.cornerRadiusMedium
                        )
                    )
                    .disabled(
                        username.trimmingCharacters(
                            in: .whitespaces
                        ).isEmpty || isLoading
                    )
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }

                if let successMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text(successMessage)
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(AppTheme.background)
        .navigationBarHidden(true)
    }

    private func sendRequest() async {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await FriendsAPI.sendRequest(username: trimmed)
            successMessage = "Request sent to @\(trimmed)"
            username = ""
        } catch let APIError.badRequest(message) {
            errorMessage = message
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        AddFriendView()
    }
}

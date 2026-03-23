import PhotosUI
import SwiftUI

struct AccountSettingsView: View {
    @Environment(AuthState.self) private var authState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var username = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    // Avatar
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var isUploadingAvatar = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                avatarSection
                fieldsSection

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.destructive)
                }

                AppButton(label: "Save Changes", isLoading: isSaving) {
                    Task { await saveProfile() }
                }
                .padding(.top, 8)

                // Danger zone separator
                Divider()
                    .background(AppTheme.border)
                    .padding(.top, 32)

                VStack(spacing: 12) {
                    Text("Danger Zone")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Text("Delete Account")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(AppTheme.destructive)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
                    }
                    .disabled(isDeleting)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        .background(AppTheme.background)
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete My Account", role: .destructive) {
                Task { await performDeletion() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all your data. This action cannot be undone.")
        }
        .navigationBarBackButtonHidden()
        .swipeBackGesture()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .principal) {
                Text("Account")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            if let user = authState.currentUser {
                displayName = user.displayName ?? ""
                username = user.username ?? ""
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task { await loadPhoto(newItem) }
        }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: 8) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                    } else if let imageURL = authState.currentUser?.avatarUrl.flatMap({ URL(string: $0) }) {
                        CachedAsyncImage(url: imageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                        } placeholder: {
                            AvatarView(size: 90)
                        }
                    } else {
                        AvatarView(size: 90)
                    }

                    Image(systemName: "camera.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.card)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.background, lineWidth: 2))
                }
            }

            if isUploadingAvatar {
                HStack(spacing: 6) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.7)
                    Text("Uploading...")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textMuted)
                }
            } else if hasAvatar {
                Button {
                    Task { await removeAvatar() }
                } label: {
                    Text("Remove Photo")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.destructive)
                }
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Fields

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Display Name")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
                AppTextField(placeholder: "Display name", text: $displayName)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Username")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
                AppTextField(placeholder: "Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
    }

    private var hasAvatar: Bool {
        avatarImage != nil || authState.currentUser?.avatarUrl != nil
    }

    // MARK: - Actions

    private func removeAvatar() async {
        errorMessage = nil
        do {
            let updated = try await AuthAPI.updateProfile(avatarUrl: "")
            authState.currentUser = updated
            avatarImage = nil
            selectedPhoto = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        avatarImage = image
        await uploadAvatar(image)
    }

    private func uploadAvatar(_ image: UIImage) async {
        guard let userId = authState.currentUser?.id else { return }
        isUploadingAvatar = true
        errorMessage = nil
        do {
            let publicURL = try await AvatarUploader.upload(image: image, userId: userId)
            let updated = try await AuthAPI.updateProfile(avatarUrl: publicURL)
            authState.currentUser = updated
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploadingAvatar = false
    }

    private func performDeletion() async {
        isDeleting = true
        errorMessage = nil
        let success = await authState.deleteAccount()
        if !success {
            errorMessage = "Failed to delete account. Please try again."
            isDeleting = false
        }
        // If success, AuthState.logout() triggers navigation to WelcomeView
        // No need to reset isDeleting -- the view will be dismissed
    }

    private func saveProfile() async {
        isSaving = true
        errorMessage = nil
        do {
            let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
            let trimmedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()
            let updated = try await AuthAPI.updateProfile(
                username: trimmedUsername.isEmpty ? nil : trimmedUsername,
                displayName: trimmedName.isEmpty ? nil : trimmedName
            )
            authState.currentUser = updated
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

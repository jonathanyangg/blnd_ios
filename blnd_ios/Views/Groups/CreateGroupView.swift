import SwiftUI

struct CreateGroupView: View {
    var onCreated: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(AppTheme.textMuted)
                    .font(.system(size: 16))

                Spacer()

                Text("New Group")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Button("Create") {
                    Task { await createGroup() }
                }
                .foregroundStyle(
                    canCreate ? .white : AppTheme.textDim
                )
                .font(.system(size: 16, weight: .semibold))
                .disabled(!canCreate)
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 16) {
                AppTextField(
                    placeholder: "Group name...",
                    text: $groupName
                )

                if isCreating {
                    HStack {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                        Text("Creating group...")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }

                Text("You can add members after creating the group.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textDim)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(AppTheme.background)
    }

    private var canCreate: Bool {
        !trimmedName.isEmpty && !isCreating
    }

    private var trimmedName: String {
        groupName.trimmingCharacters(in: .whitespaces)
    }

    private func createGroup() async {
        guard canCreate else { return }
        isCreating = true
        errorMessage = nil

        do {
            _ = try await GroupsAPI.createGroup(name: trimmedName)
            await onCreated?()
            dismiss()
        } catch let APIError.badRequest(message) {
            errorMessage = message
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreating = false
    }
}

#Preview {
    CreateGroupView()
}

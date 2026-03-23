import SwiftUI

struct CreateGroupView: View {
    var onCreated: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var createdGroup: GroupDetailResponse?

    var body: some View {
        if let group = createdGroup {
            AddGroupMemberSheet(
                groupId: group.id,
                onMemberAdded: { _ in }
            )
            .background(AppTheme.background)
        } else {
            createForm
        }
    }

    private var createForm: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(AppTheme.textMuted)
                    .font(.system(size: 16))

                Spacer()

                Text("New Blend")
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
            let group = try await GroupsAPI.createGroup(
                name: trimmedName
            )
            UserActionCache.shared.invalidateGroups()
            await onCreated?()
            withAnimation { createdGroup = group }
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

import SwiftUI

struct CreateGroupView: View {
    var onCreated: ((GroupDetailResponse) async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var groupName = "Movie night"
    @State private var isCreating = false
    @State private var errorMessage: UserFacingError?
    @State private var createdGroup: GroupDetailResponse?
    @State private var staged: [String: BlendInvite.Candidate] = [:]

    var body: some View {
        createForm
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
                .accessibilityIdentifier("blends.create.submit")
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 8) {
                AppTextField(
                    placeholder: "Blend name...",
                    text: $groupName
                )
                .accessibilityIdentifier("blends.name")
                .onChange(of: groupName) { _, newValue in
                    if newValue.count > 30 {
                        groupName = String(newValue.prefix(30))
                    }
                }
                if let note = errorMessage?.inline(for: "name") {
                    InlineError(message: note)
                }

                HStack {
                    Spacer()
                    Text("\(trimmedName.count)/30")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textDim)
                }

                if isCreating {
                    HStack {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                        Text("Creating blend...")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .padding(.top, 8)
                }

                if let errorMessage, errorMessage.fields.isEmpty {
                    InlineError(message: errorMessage)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)

            Text(staged.isEmpty ? "Add people" : "Adding \(staged.count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)

            BlendMemberPicker(
                excludedIds: [KeychainManager.readString(key: "userId") ?? ""],
                selectedIds: Set(staged.keys),
                busyId: nil
            ) { candidate in
                if staged.removeValue(forKey: candidate.id) == nil {
                    staged[candidate.id] = candidate
                }
            }
            .disabled(isCreating)
        }
        .background(AppTheme.background)
    }

    private var canCreate: Bool {
        !trimmedName.isEmpty && !isCreating
    }

    private var trimmedName: String {
        groupName.trimmingCharacters(in: .whitespaces)
    }

    /// Creates the blend once, then adds every staged member. A retry only re-adds the ones that failed.
    private func createGroup() async {
        guard canCreate else { return }
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        var group: GroupDetailResponse
        if let createdGroup {
            group = createdGroup
        } else {
            do {
                group = try await GroupsService.createGroup(name: trimmedName)
                Analytics.groupCreated()
                createdGroup = group
            } catch {
                errorMessage = UserFacingError.capture(error, screen: "CreateBlend")
                return
            }
        }

        for candidate in staged.values {
            do {
                group = try await GroupsService.addMember(groupId: group.id, username: candidate.username)
                staged[candidate.id] = nil
            } catch {
                errorMessage = UserFacingError.capture(error, screen: "CreateBlend")
            }
        }
        guard staged.isEmpty else { return }
        await onCreated?(group)
        dismiss()
    }
}

#Preview {
    CreateGroupView()
}

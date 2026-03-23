import SwiftUI

struct GroupMembersSheet: View {
    let groupId: Int
    @Binding var group: GroupDetailResponse?
    let isOwner: Bool
    var onGroupDeleted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showAddMember = false
    @State private var removingId: String?
    @State private var confirmRemoveId: String?
    @State private var showLeaveConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isLeaving = false
    @State private var isDeleting = false

    private var currentUserId: String {
        KeychainManager.readString(key: "userId") ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let group {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(group.members) { member in
                            memberRow(member, group: group)
                        }
                    }
                }

                Divider().background(AppTheme.cardSecondary)
                actionButtons
            }
        }
        .sheet(isPresented: $showAddMember) {
            AddGroupMemberSheet(groupId: groupId) { updated in
                group = updated
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.background)
        }
        .confirmationDialog(
            "Remove member?",
            isPresented: Binding(
                get: { confirmRemoveId != nil },
                set: { if !$0 { confirmRemoveId = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let uid = confirmRemoveId {
                    Task { await removeMember(uid) }
                }
            }
        }
        .confirmationDialog(
            "Leave this blend?",
            isPresented: $showLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) {
                Task { await leaveGroup() }
            }
        } message: {
            Text("You'll need to be re-invited to rejoin.")
        }
        .confirmationDialog(
            "Delete this blend?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteGroup() }
            }
        } message: {
            Text("This will permanently delete the blend and all its data.")
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Text("Done")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textMuted)
            }
            Spacer()
            Text("Members")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button { showAddMember = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private func memberRow(
        _ member: GroupMemberResponse,
        group: GroupDetailResponse
    ) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: member.avatarUrl, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName ?? member.username)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("@\(member.username)")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            if member.id == group.createdBy {
                Text("Owner")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textDim)
            } else if member.id != currentUserId {
                if removingId == member.id {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                } else {
                    Button {
                        confirmRemoveId = member.id
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textDim)
                            .frame(width: 28, height: 28)
                            .background(AppTheme.card)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                showLeaveConfirm = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                    Text("Leave Blend")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
            .disabled(isLeaving)

            if isOwner {
                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text("Delete Blend")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.red.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                }
                .disabled(isDeleting)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    private func removeMember(_ userId: String) async {
        removingId = userId
        do {
            try await GroupsAPI.kickMember(
                groupId: groupId,
                userId: userId
            )
            let updated = try await GroupsAPI.getGroup(
                groupId: groupId
            )
            group = updated
        } catch {
            print("[GroupMembersSheet] Remove failed: \(error)")
        }
        removingId = nil
    }

    private func leaveGroup() async {
        isLeaving = true
        do {
            try await GroupsAPI.leaveGroup(groupId: groupId)
            UserActionCache.shared.invalidateGroups()
            dismiss()
            onGroupDeleted?()
        } catch {
            print("[GroupMembersSheet] Leave failed: \(error)")
        }
        isLeaving = false
    }

    private func deleteGroup() async {
        isDeleting = true
        do {
            try await GroupsAPI.deleteGroup(groupId: groupId)
            UserActionCache.shared.invalidateGroups()
            dismiss()
            onGroupDeleted?()
        } catch {
            print("[GroupMembersSheet] Delete failed: \(error)")
        }
        isDeleting = false
    }
}

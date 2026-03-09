import SwiftUI

struct GroupMembersSheet: View {
    let groupId: Int
    @Binding var group: GroupDetailResponse?
    let isOwner: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var showAddMember = false
    @State private var removingId: String?
    @State private var confirmRemoveId: String?

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
            } else if isOwner {
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
}

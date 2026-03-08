import SwiftUI

struct AddGroupMemberSheet: View {
    let groupId: Int
    let onMemberAdded: (GroupDetailResponse) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FriendResponse] = []
    @State private var isLoadingFriends = true
    @State private var query = ""
    @State private var addingId: String?
    @State private var addedIds: Set<String> = []
    @State private var errorMessage: String?

    @FocusState private var isFieldFocused: Bool

    private var filteredFriends: [FriendResponse] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return friends }
        return friends.filter {
            $0.username.lowercased().contains(trimmed)
                || ($0.displayName?.lowercased().contains(trimmed) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            if isLoadingFriends {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 40)
                Spacer()
            } else if friends.isEmpty {
                Text("Add some friends first to invite them")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.top, 40)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredFriends) { friend in
                            friendRow(friend)
                        }
                    }
                }
            }
        }
        .task {
            await loadFriends()
            isFieldFocused = true
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textMuted)
            }
            Spacer()
            Text("Add Member")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Text("Cancel").font(.system(size: 15)).opacity(0)
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textDim)
            TextField("Search friends...", text: $query)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFieldFocused)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textDim)
                }
            }
        }
        .padding(14)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
    }

    private func friendRow(_ friend: FriendResponse) -> some View {
        HStack(spacing: 12) {
            AvatarView(size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName ?? friend.username)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("@\(friend.username)")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            if addedIds.contains(friend.id) {
                Text("Added")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppTheme.card)
                    .clipShape(Capsule())
            } else {
                Button {
                    Task { await addFriend(friend) }
                } label: {
                    if addingId == friend.id {
                        ProgressView()
                            .tint(.black)
                            .controlSize(.small)
                            .frame(width: 50)
                    } else {
                        Text("Add")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.white)
                .clipShape(Capsule())
                .disabled(addingId != nil)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    private func loadFriends() async {
        do {
            let response = try await FriendsAPI.listFriends()
            friends = response.friends
        } catch {
            print("[AddGroupMemberSheet] Failed to load friends: \(error)")
        }
        isLoadingFriends = false
    }

    private func addFriend(_ friend: FriendResponse) async {
        addingId = friend.id
        errorMessage = nil
        do {
            let updated = try await GroupsAPI.addMember(
                groupId: groupId,
                username: friend.username
            )
            addedIds.insert(friend.id)
            onMemberAdded(updated)
        } catch let APIError.badRequest(message) {
            errorMessage = message
        } catch {
            errorMessage = error.localizedDescription
        }
        addingId = nil
    }
}

import SwiftUI

struct AddGroupMemberSheet: View {
    let groupId: Int
    var existingMemberIds: Set<String> = []
    let onMemberAdded: (GroupDetailResponse) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthState.self) private var authState
    @State private var addingId: String?
    @State private var addedIds: Set<String> = []
    @State private var errorMessage: UserFacingError?
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if let errorMessage {
                InlineError(message: errorMessage)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            BlendMemberPicker(
                excludedIds: existingMemberIds,
                selectedIds: addedIds,
                busyId: addingId
            ) { candidate in
                guard !addedIds.contains(candidate.id) else { return }
                Task { await add(candidate) }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(source: .groupLimit)
                .environment(authState)
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
            Button { dismiss() } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("blends.members.done")
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private func add(_ candidate: BlendInvite.Candidate) async {
        addingId = candidate.id
        errorMessage = nil
        do {
            let updated = try await GroupsService.addMember(
                groupId: groupId,
                username: candidate.username
            )
            addedIds.insert(candidate.id)
            onMemberAdded(updated)
        } catch let error as APIError where error.opensPaywall {
            showPaywall = true
        } catch {
            errorMessage = UserFacingError.capture(error, screen: "BlendMembers")
        }
        addingId = nil
    }
}

/// Username search (friends first, then anyone) plus a share-sheet invite. Tap a row to pick that user.
struct BlendMemberPicker: View {
    var excludedIds: Set<String>
    var selectedIds: Set<String>
    var busyId: String?
    let onTap: (BlendInvite.Candidate) -> Void

    @Environment(AuthState.self) private var authState
    @State private var friends: [FriendResponse] = []
    @State private var searchResults: [UserSearchResult] = []
    @State private var isLoadingFriends = true
    @State private var query = ""
    @State private var loadError: UserFacingError?

    private var candidates: [BlendInvite.Candidate] {
        BlendInvite.candidates(
            friends: friends,
            searchResults: searchResults,
            query: query,
            excluding: excludedIds
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            ShareLink(item: BlendInvite.shareText(username: authState.currentUser?.username)) {
                Label("Invite a friend", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("blends.invite.share")
            .padding(.horizontal, 24)
            .padding(.vertical, 8)

            if let loadError {
                InlineError(message: loadError)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            if isLoadingFriends {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 40)
                Spacer()
            } else if candidates.isEmpty {
                Text(query.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Search a username to add anyone on blnd"
                    : "No users found")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.top, 40)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(candidates) { candidate in
                            row(candidate)
                        }
                    }
                }
            }
        }
        .task { await loadFriends() }
        .task(id: query) { await search() }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textDim)
            TextField("Search username...", text: $query)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("blends.members.search")
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

    private func row(_ candidate: BlendInvite.Candidate) -> some View {
        let isSelected = selectedIds.contains(candidate.id)
        return Button { onTap(candidate) } label: {
            HStack(spacing: 12) {
                AvatarView(url: candidate.avatarUrl, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.displayName ?? candidate.username)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(candidate.isFriend ? "@\(candidate.username) · Friend" : "@\(candidate.username)")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                }

                Spacer()

                if busyId == candidate.id {
                    ProgressView().tint(.white).controlSize(.small)
                } else {
                    Text(isSelected ? "Added" : "Add")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.textMuted : .black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(isSelected ? AppTheme.card : .white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busyId != nil)
        .accessibilityIdentifier("blends.member.\(candidate.username)")
    }

    private func loadFriends() async {
        do {
            friends = try await FriendsAPI.listFriends().friends
        } catch is CancellationError {
            return
        } catch {
            loadError = UserFacingError.capture(error, screen: "BlendMembers")
        }
        isLoadingFriends = false
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        do {
            searchResults = try await AuthAPI.searchUsers(query: trimmed).results
            loadError = nil
        } catch is CancellationError {
            return
        } catch {
            loadError = UserFacingError.capture(error, screen: "BlendMemberSearch")
        }
    }
}

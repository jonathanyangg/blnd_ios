import Contacts
import PostHog
import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [UserSearchResult] = []
    @State private var matchingFriends: [FriendResponse] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    // Suggestions
    @State private var contactSuggestions: [SuggestedFriendResponse] = []
    @State private var mutualSuggestions: [SuggestedFriendResponse] = []
    @State private var isSuggestionsLoading = true

    // Request state
    @State private var sendingTo: String?
    @State private var sentTo: Set<String> = []
    @State private var cancelledIds: Set<String> = []
    @State private var errorMessage: String?
    @State private var unrequestTarget: (id: String, friendshipId: Int)?

    @FocusState private var isFieldFocused: Bool

    private var showSuggestions: Bool {
        query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasSuggestions: Bool {
        !contactSuggestions.isEmpty || !mutualSuggestions.isEmpty
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

            if showSuggestions {
                suggestionsContent
            } else {
                searchResults
            }
        }
        .background(AppTheme.background)
        .navigationBarHidden(true)
        .onAppear { isFieldFocused = true }
        .task { await loadSuggestions() }
        .alert("Cancel Request", isPresented: showUnrequestAlert) {
            Button("Keep", role: .cancel) { unrequestTarget = nil }
            Button("Withdraw", role: .destructive) {
                if let target = unrequestTarget {
                    Task { await withdrawRequest(id: target.id, friendshipId: target.friendshipId) }
                }
            }
        } message: {
            Text("Withdraw this friend request?")
        }
    }

    private var showUnrequestAlert: Binding<Bool> {
        Binding(get: { unrequestTarget != nil }, set: { if !$0 { unrequestTarget = nil } })
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .medium))
            }

            Text("Find Friends")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textDim)
            TextField("Search by username...", text: $query)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFieldFocused)
                .onChange(of: query) { _, newValue in
                    debounceSearch(newValue)
                }
            if isSearching {
                ProgressView()
                    .tint(AppTheme.textMuted)
                    .controlSize(.small)
            } else if !query.isEmpty {
                Button {
                    query = ""
                    results = []
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

    // MARK: - Suggestions

    private var suggestionsContent: some View {
        Group {
            if isSuggestionsLoading {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 40)
                Spacer()
            } else if hasSuggestions {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if !contactSuggestions.isEmpty {
                            sectionHeader("FROM YOUR CONTACTS")
                            ForEach(contactSuggestions) { suggestion in
                                suggestionRow(suggestion)
                            }
                        }

                        if !mutualSuggestions.isEmpty {
                            sectionHeader("PEOPLE YOU MAY KNOW")
                                .padding(.top, contactSuggestions.isEmpty ? 0 : 12)
                            ForEach(mutualSuggestions) { suggestion in
                                suggestionRow(suggestion)
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("Search for friends by username")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(.top, 40)
                Spacer()
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textDim)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func suggestionRow(
        _ suggestion: SuggestedFriendResponse
    ) -> some View {
        NavigationLink {
            FriendProfileView(friend: FriendResponse(
                friendshipId: nil,
                id: suggestion.id,
                username: suggestion.username,
                displayName: suggestion.displayName,
                avatarUrl: suggestion.avatarUrl
            ))
        } label: {
            HStack(spacing: 12) {
                AvatarView(
                    url: suggestion.avatarUrl, size: 44
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        suggestion.displayName
                            ?? suggestion.username
                    )
                    .font(.system(
                        size: 15, weight: .semibold
                    ))
                    .foregroundStyle(.white)

                    if suggestion.source == "mutual", suggestion.mutualCount > 0 {
                        Text(
                            "\(suggestion.mutualCount) mutual friend\(suggestion.mutualCount == 1 ? "" : "s")"
                        )
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                    } else {
                        Text("@\(suggestion.username)")
                            .font(.system(size: 13))
                            .foregroundStyle(
                                AppTheme.textMuted
                            )
                    }
                }

                Spacer()

                addButton(
                    id: suggestion.id,
                    username: suggestion.username
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Results

    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !matchingFriends.isEmpty {
                    sectionHeader("YOUR FRIENDS")
                    ForEach(matchingFriends) { friend in
                        friendRow(friend)
                    }
                }

                let friendIds = Set(matchingFriends.map(\.id))
                let filtered = results.filter { !friendIds.contains($0.id) }
                if !filtered.isEmpty {
                    sectionHeader("ADD FRIENDS")
                        .padding(.top, matchingFriends.isEmpty ? 0 : 12)
                    ForEach(filtered) { user in
                        userRow(user)
                    }
                }
            }
        }
    }

    private func friendRow(_ friend: FriendResponse) -> some View {
        NavigationLink {
            FriendProfileView(friend: friend)
        } label: {
            HStack(spacing: 12) {
                AvatarView(url: friend.avatarUrl, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName ?? friend.username)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("@\(friend.username)")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func userRow(_ user: UserSearchResult) -> some View {
        NavigationLink {
            FriendProfileView(friend: FriendResponse(
                friendshipId: nil,
                id: user.id,
                username: user.username,
                displayName: user.displayName,
                avatarUrl: user.avatarUrl
            ))
        } label: {
            HStack(spacing: 12) {
                AvatarView(url: user.avatarUrl, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        user.displayName ?? user.username
                    )
                    .font(.system(
                        size: 15, weight: .semibold
                    ))
                    .foregroundStyle(.white)
                    Text("@\(user.username)")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                }

                Spacer()

                addButton(
                    id: user.id,
                    username: user.username,
                    status: user.friendshipStatus,
                    friendshipId: user.friendshipId
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Buttons

extension AddFriendView {
    @ViewBuilder
    func addButton(
        id: String, username: String,
        status: String? = nil, friendshipId: Int? = nil
    ) -> some View {
        if cancelledIds.contains(id) {
            addPill(id: id, username: username)
        } else if status == "accepted" {
            statusPill("Friends")
        } else if status == "pending" || sentTo.contains(id) {
            pendingPill(id: id, friendshipId: friendshipId)
        } else {
            addPill(id: id, username: username)
        }
    }

    func addPill(id: String, username: String) -> some View {
        Button {
            Task { await sendRequest(id: id, username: username) }
        } label: {
            if sendingTo == id {
                ProgressView().tint(.black).controlSize(.small).frame(width: 50)
            } else {
                Text("Add").font(.system(size: 13, weight: .semibold))
            }
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(.white).clipShape(Capsule())
        .disabled(sendingTo != nil)
    }

    func pendingPill(id: String, friendshipId: Int?) -> some View {
        Button {
            if let fid = friendshipId { unrequestTarget = (id, fid) }
        } label: {
            Text("Pending").font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(AppTheme.card).clipShape(Capsule())
        }
    }

    func statusPill(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.textMuted)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(AppTheme.card).clipShape(Capsule())
    }
}

// MARK: - Data

extension AddFriendView {
    func loadSuggestions() async {
        await syncContactsIfAllowed()
        do {
            let response = try await FriendsAPI.getSuggestions()
            contactSuggestions = response.contacts
            mutualSuggestions = response.mutuals
        } catch {}
        isSuggestionsLoading = false
    }

    func syncContactsIfAllowed() async {
        let status = CNContactStore.authorizationStatus(
            for: .contacts
        )
        guard status == .authorized else { return }
        let numbers = await ContactsHelper.fetchPhoneNumbers()
        guard !numbers.isEmpty else { return }
        try? await FriendsAPI.uploadContacts(
            phoneNumbers: numbers
        )
    }

    func debounceSearch(_ value: String) {
        searchTask?.cancel()
        let trimmed = value.trimmingCharacters(
            in: .whitespaces
        )
        guard !trimmed.isEmpty else {
            results = []
            matchingFriends = []
            isSearching = false
            return
        }
        let lowered = trimmed.lowercased()
        matchingFriends = UserActionCache.shared.friends.filter { friend in
            friend.username.lowercased().contains(lowered) ||
                (friend.displayName?.lowercased().contains(lowered) ?? false)
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(
                for: .milliseconds(300)
            )
            guard !Task.isCancelled else { return }
            do {
                let resp = try await AuthAPI.searchUsers(
                    query: trimmed
                )
                if !Task.isCancelled {
                    results = resp.results
                }
            } catch {
                if !Task.isCancelled { results = [] }
            }
            isSearching = false
        }
    }

    func sendRequest(
        id: String, username: String
    ) async {
        sendingTo = id
        errorMessage = nil
        do {
            _ = try await FriendsAPI.sendRequest(
                username: username
            )
            sentTo.insert(id)
            PostHogSDK.shared.capture("friend_request_sent")
            contactSuggestions.removeAll { $0.id == id }
            mutualSuggestions.removeAll { $0.id == id }
        } catch let APIError.badRequest(message) {
            errorMessage = message
        } catch {
            errorMessage = error.localizedDescription
        }
        sendingTo = nil
    }

    private func withdrawRequest(id: String, friendshipId: Int) async {
        do {
            try await FriendsAPI.removeFriend(friendshipId: friendshipId)
            sentTo.remove(id)
            cancelledIds.insert(id)
        } catch {
            errorMessage = error.localizedDescription
        }
        unrequestTarget = nil
    }
}

#Preview {
    NavigationStack {
        AddFriendView()
    }
}

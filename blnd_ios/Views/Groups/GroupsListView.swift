import SwiftUI

struct GroupsListView: View {
    @Environment(TabState.self) private var tabState
    @Environment(DeepLinkState.self) private var deepLinkState
    @State private var groups: [GroupResponse] = []
    @State private var isLoading = true
    @State private var errorMessage: UserFacingError?
    @State private var showCreateGroup = false
    @State private var deepLinkGroupId: Int?
    @State private var searchQuery = ""
    @State private var resolvedNames: [Int: [String]] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Blends")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            showCreateGroup = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .accessibilityIdentifier("blends.create")
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    if !groups.isEmpty {
                        SearchBar(text: $searchQuery, placeholder: "Search blends...")
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                    }

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 40)
                    } else if let error = errorMessage {
                        ErrorStateView(message: error) {
                            Task { await loadGroups() }
                        }
                        .padding(.top, 40)
                    } else if groups.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.3")
                                .font(.system(size: 36))
                                .foregroundStyle(AppTheme.textDim)
                            Text("No blends yet")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Blend your taste with friends to find movies together")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        .padding(.top, 60)
                    } else {
                        let query = searchQuery.trimmingCharacters(in: .whitespaces)
                        let filtered = query.isEmpty
                            ? groups
                            : groups.filter {
                                title(for: $0).localizedCaseInsensitiveContains(query)
                            }
                        ForEach(filtered) { group in
                            NavigationLink {
                                GroupDetailView(groupId: group.id)
                            } label: {
                                GroupCardRow(group: group, title: title(for: group))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("blends.group")
                        }
                    }
                }
            }
            .background(AppTheme.background)
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView(onCreated: { await loadGroups() })
                    .presentationBackground(AppTheme.background)
            }
            .task { await loadGroups() }
            .refreshable { await loadGroups() }
            .onChange(of: showCreateGroup) {
                if !showCreateGroup {
                    Task { await loadGroups() }
                }
            }
            .navigationDestination(item: $deepLinkGroupId) { groupId in
                GroupDetailView(groupId: groupId)
            }
            .onChange(of: deepLinkState.pending) { _, newValue in
                if case let .groupDetail(groupId) = newValue {
                    deepLinkGroupId = groupId
                    deepLinkState.pending = nil
                }
            }
            .onAppear {
                if case let .groupDetail(groupId) = deepLinkState.pending {
                    deepLinkGroupId = groupId
                    deepLinkState.pending = nil
                }
            }
        }
        .id(tabState.navigationReset)
    }

    private func loadGroups() async {
        errorMessage = nil
        do {
            let result = try await GroupsAPI.listGroups()
            groups = result.groups
            resolvedNames = await GroupsAPI.memberNamesForUnnamedGroups(groups)
        } catch is CancellationError {
            return
        } catch {
            if groups.isEmpty {
                errorMessage = UserFacingError.capture(error, screen: "Groups")
            }
        }
        isLoading = false
    }

    private func title(for group: GroupResponse) -> String {
        group.displayTitle(resolvedNames: resolvedNames[group.id] ?? [])
    }
}

// MARK: - Group Card Row

private struct GroupCardRow: View {
    let group: GroupResponse
    let title: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(group.memberCount) members")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            HStack(spacing: 0) {
                ForEach(
                    Array(group.memberAvatars.prefix(3).enumerated()),
                    id: \.offset
                ) { index, avatarUrl in
                    AvatarView(url: avatarUrl, size: 28, overlap: index > 0)
                }
                if group.memberCount > 3 {
                    ZStack {
                        Circle()
                            .fill(AppTheme.card)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().stroke(
                                    AppTheme.background,
                                    lineWidth: 2
                                )
                            )
                        Text("+\(group.memberCount - 3)")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, -10)
                }
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}

#Preview {
    GroupsListView()
}

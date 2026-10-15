import SwiftUI

struct GroupsListView: View {
    @Environment(TabState.self) private var tabState
    @Environment(DeepLinkState.self) private var deepLinkState
    @State private var groups: [GroupResponse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateGroup = false
    @State private var deepLinkGroupId: Int?
    @State private var searchQuery = ""

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
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showCreateGroup = true
                        } label: {
                            Text("New")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.white, in: Capsule())
                        }
                        .accessibilityLabel("Create a blend")
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
                        VStack(spacing: 12) {
                            Image(systemName: "person.3")
                                .font(.system(size: 36))
                                .foregroundStyle(AppTheme.textDim)
                            Text("No blends yet")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Start a blend, then invite friends to pick movies together.")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textMuted)
                                .multilineTextAlignment(.center)
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showCreateGroup = true
                            } label: {
                                Text("Create a blend")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .background(.white, in: Capsule())
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 60)
                    } else {
                        let filtered = searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
                            ? groups
                            : groups.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
                        ForEach(filtered) { group in
                            NavigationLink {
                                GroupDetailView(groupId: group.id)
                            } label: {
                                GroupCardRow(group: group)
                            }
                            .buttonStyle(.plain)
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
        } catch is CancellationError {
            return
        } catch {
            if groups.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}

// MARK: - Group Card Row

private struct GroupCardRow: View {
    let group: GroupResponse

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
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
